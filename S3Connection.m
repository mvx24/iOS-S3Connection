//
//  S3Connection.m
//
//  Copyright 2014 Symbiotic Software. All rights reserved.
//
//  http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html
//

#import "S3Connection.h"
#import "NSData+Encoding.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <MobileCoreServices/MobileCoreServices.h>

#define S3_URL						@"http://%@.s3.amazonaws.com/%@"
#define S3_SECURE_URL				@"https://%@.s3.amazonaws.com/%@"

#define STRING_S3_BADCONNECTION		@"Could not establish connection."
#define STRING_S3_MISSINGPARAMS		@"Missing parameters required for this operation."
#define STRING_S3_BADPATH			@"Could not open file."
#define STRING_S3_HTTPERROR			@"There was a problem with the request."

@interface S3Connection () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
	NSURLConnection *_connection;
	NSInteger _statusCode;
	NSMutableData *_responseData;
}

@property (nonatomic, copy) S3CompletionHandler completionHandler;

- (NSString *)authorizationHeader:(NSString *)verb withMD5:(NSString *)md5 contentType:(NSString *)contentType date:(NSString *)date resource:(NSString *)resource;
- (NSString *)dateHeader;
- (NSString *)mimeType:(NSString *)path;

@end

@implementation S3Connection

- (id)initWithAccessKeyId:(NSString *)accessKeyId secretAccessKey:(NSString *)secretAccessKey
{
	if(self = [super init])
	{
		self.accessKeyId = accessKeyId;
		self.secretAccessKey = secretAccessKey;
	}
	return self;
}

- (void)dealloc
{
	[_connection cancel];
	_connection = nil;
	if(_responseData)
	{
		[_responseData release];
		_responseData = nil;
	}
	self.accessKeyId = nil;
	self.secretAccessKey = nil;
	self.bucket = nil;
	self.extraHeaders = nil;
	self.completionHandler = nil;
	[super dealloc];
}

- (void)cancelCurrentRequest
{
	BOOL activeConnection = (_connection != nil);
	[_connection cancel];
	_connection = nil;
	if(_responseData)
	{
		[_responseData release];
		_responseData = nil;
	}
	if(activeConnection)
		[self release];
}

// http://docs.aws.amazon.com/AmazonS3/latest/dev/RESTAuthentication.html
- (NSString *)authorizationHeader:(NSString *)verb withMD5:(NSString *)md5 contentType:(NSString *)contentType date:(NSString *)date resource:(NSString *)resource
{
	NSString *signature;
	NSString *canonicalizedResource;
	NSString *stringToSign;
	CCHmacContext ctx;
	unsigned char hmac[20];
	
	if(!md5)
		md5 = @"";
	if(!contentType)
		contentType = @"";
	
	// Create the string to sign
	if([resource hasPrefix:@"/"])
		canonicalizedResource = [NSString stringWithFormat:@"/%@%@", _bucket, resource];
	else
		canonicalizedResource = [NSString stringWithFormat:@"/%@/%@", _bucket, resource];
	stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@", verb, md5, contentType, date, canonicalizedResource];
	
	// Create the signature
	CCHmacInit(&ctx, kCCHmacAlgSHA1, [_secretAccessKey UTF8String], [_secretAccessKey length]);
	CCHmacUpdate(&ctx, [stringToSign UTF8String], [stringToSign length]);
	CCHmacFinal(&ctx, hmac);
	signature = [[NSData dataWithBytesNoCopy:hmac length:sizeof(hmac) freeWhenDone:NO] base64String];
	
	return [NSString stringWithFormat:@"AWS %@:%@", _accessKeyId, signature];
}

- (NSString *)dateHeader
{
	NSDateFormatter *dateFormatter;
	dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss +0000"];
	[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	return [dateFormatter stringFromDate:[NSDate date]];
}

- (NSString *)mimeType:(NSString *)path
{
	CFStringRef uti, mime;
	NSString *contentType = nil;
	NSString *extension;

	extension = [path pathExtension];
	if([extension length])
	{
		uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)extension, NULL);
		if(uti)
		{
			mime = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
			if(mime)
			{
				contentType = [NSString stringWithString:(NSString *)mime];
				CFRelease(mime);
			}
			CFRelease(uti);
		}
	}
	return contentType;
}

- (void)uploadData:(NSData *)data withKey:(NSString *)key contentType:(NSString *)contentType options:(NSUInteger)options completionHandler:(S3CompletionHandler)completionHandler
{
	NSURL *url;
	NSMutableURLRequest *request;
	NSString *md5;
	NSString *authorization;
	NSString *date;
	CC_MD5_CTX ctx;
	uint8_t hash[16];
	
	if(![data length] || ![key length])
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:ERROR_DOMAIN_S3CONNECTION code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_MISSINGPARAMS}]);
		return;
	}
	
	[self retain];
	[self cancelCurrentRequest];

	// Don't allow keys to start with a /
	if([key hasPrefix:@"/"])
		key = [key substringFromIndex:1];

	// Calculate the MD5 and other headers
	if(![contentType length])
		contentType = [self mimeType:key];
	CC_MD5_Init(&ctx);
	CC_MD5_Update(&ctx, [data bytes], [data length]);
	CC_MD5_Final(hash, &ctx);
	md5 = [[NSData dataWithBytesNoCopy:hash length:sizeof(hash) freeWhenDone:NO] base64String];
	date = [self dateHeader];
	authorization = [self authorizationHeader:@"PUT" withMD5:md5 contentType:contentType date:date resource:key];
	
	// Setup the request
	if(options & S3_HTTPS)
		url = [NSURL URLWithString:[NSString stringWithFormat:S3_SECURE_URL, _bucket, key]];
	else
		url = [NSURL URLWithString:[NSString stringWithFormat:S3_URL, _bucket, key]];
	request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
	[request setHTTPMethod:@"PUT"];
	// Check for the gzip magic number and add the Content-Encoding header
	if(options & S3_DETECT_GZIP && ((const uint8_t *)[data bytes])[0] == 0x1f && ((const uint8_t *)[data bytes])[1] == 0x8b)
		[request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
	if(options & S3_NO_CACHE)
		[request setValue:@"no-cache" forKeyPath:@"Cache-Control"];
	if(options & S3_PERMANENT_CACHE)
		[request setValue:@"max-age=315360000" forKeyPath:@"Cache-Control"];
	if(options & S3_REDUCED_REDUNDANCY)
		[request setValue:@"REDUCED_REDUNDANCY" forKeyPath:@"x-amz-storage-class"];
	if([contentType length])
		[request setValue:contentType forHTTPHeaderField:@"Content-Type"];
	[request setValue:[NSString stringWithFormat:@"%u", [data length]] forHTTPHeaderField:@"Content-Length"];
	[request setValue:md5 forHTTPHeaderField:@"Content-MD5"];
	[request setValue:date forHTTPHeaderField:@"Date"];
	[request setValue:authorization forHTTPHeaderField:@"Authorization"];
	if([_extraHeaders count])
	{
		for(NSString *header in _extraHeaders)
			[request addValue:[_extraHeaders objectForKey:header] forHTTPHeaderField:header];
	}
	[request setHTTPBody:data];
	
	// Start the connection
	_connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if(_connection != nil)
	{
		self.completionHandler = completionHandler;
	}
	else
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:ERROR_DOMAIN_S3CONNECTION code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_BADCONNECTION}]);
		[self release];
	}
}

- (void)uploadFile:(NSString *)path withKey:(NSString *)key options:(NSUInteger)options completionHandler:(S3CompletionHandler)completionHandler
{
	NSInputStream *inputStream;
	NSURL *url;
	NSMutableURLRequest *request;
	NSString *contentType = nil;
	NSString *md5;
	NSString *authorization;
	NSString *date;
	CC_MD5_CTX ctx;
	uint8_t hash[16];
	uint8_t buf[1024];
	uint8_t head[2];
	int len;
	size_t fileSize = 0;
	
	if(![path length] || ![key length])
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:ERROR_DOMAIN_S3CONNECTION code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_MISSINGPARAMS}]);
		return;
	}
	
	inputStream = [NSInputStream inputStreamWithFileAtPath:path];
	if(!inputStream)
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:ERROR_DOMAIN_S3CONNECTION code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_BADPATH}]);
		return;
	}
	
	[self retain];
	[self cancelCurrentRequest];

	// Don't allow keys to start with a /
	if([key hasPrefix:@"/"])
		key = [key substringFromIndex:1];

	// Calculate the MD5 and other headers
	contentType = [self mimeType:path];
	CC_MD5_Init(&ctx);
	[inputStream open];
	while((len = [inputStream read:buf maxLength:sizeof(buf)]) > 0)
	{
		if(!fileSize)
		{
			head[0] = buf[0];
			head[1] = buf[1];
		}
		CC_MD5_Update(&ctx, buf, len);
		fileSize += len;
	}
	[inputStream close];
	CC_MD5_Final(hash, &ctx);
	md5 = [[NSData dataWithBytesNoCopy:hash length:sizeof(hash) freeWhenDone:NO] base64String];
	date = [self dateHeader];
	authorization = [self authorizationHeader:@"PUT" withMD5:md5 contentType:contentType date:date resource:key];
	
	// Setup the request
	if(options & S3_HTTPS)
		url = [NSURL URLWithString:[NSString stringWithFormat:S3_SECURE_URL, _bucket, key]];
	else
		url = [NSURL URLWithString:[NSString stringWithFormat:S3_URL, _bucket, key]];
	request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
	[request setHTTPMethod:@"PUT"];
	// Check for the gzip magic number and add the Content-Encoding header
	if(options & S3_DETECT_GZIP && head[0] == 0x1f && head[1] == 0x8b)
		[request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
	if(options & S3_NO_CACHE)
		[request setValue:@"no-cache" forKeyPath:@"Cache-Control"];
	if(options & S3_PERMANENT_CACHE)
		[request setValue:@"max-age=315360000" forKeyPath:@"Cache-Control"];
	if(options & S3_REDUCED_REDUNDANCY)
		[request setValue:@"REDUCED_REDUNDANCY" forKeyPath:@"x-amz-storage-class"];
	if([contentType length])
		[request setValue:contentType forHTTPHeaderField:@"Content-Type"];
	[request setValue:[NSString stringWithFormat:@"%lu", fileSize] forHTTPHeaderField:@"Content-Length"];
	[request setValue:md5 forHTTPHeaderField:@"Content-MD5"];
	[request setValue:date forHTTPHeaderField:@"Date"];
	[request setValue:authorization forHTTPHeaderField:@"Authorization"];
	if([_extraHeaders count])
	{
		for(NSString *header in _extraHeaders)
			[request addValue:[_extraHeaders objectForKey:header] forHTTPHeaderField:header];
	}
	[request setHTTPBodyStream:[NSInputStream inputStreamWithFileAtPath:path]];
	
	// Setup the connection
	_connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if(_connection != nil)
	{
		self.completionHandler = completionHandler;
	}
	else
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:ERROR_DOMAIN_S3CONNECTION code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_BADCONNECTION}]);
		[self release];
	}
}

+ (void)uploadData:(NSData *)data intoBucket:(NSString *)bucket withKey:(NSString *)key contentType:(NSString *)contentType options:(NSUInteger)options accessKeyId:(NSString *)accessKeyId secretAccessKey:(NSString *)secretAccessKey completionHandler:(S3CompletionHandler)completionHandler
{
	S3Connection *s3connection;
	s3connection = [[[S3Connection alloc] initWithAccessKeyId:accessKeyId secretAccessKey:secretAccessKey] autorelease];
	s3connection.bucket = bucket;
	[s3connection uploadData:data withKey:key contentType:contentType options:options completionHandler:completionHandler];
}

+ (void)uploadFile:(NSString *)path intoBucket:(NSString *)bucket withKey:(NSString *)key options:(NSUInteger)options accessKeyId:(NSString *)accessKeyId secretAccessKey:(NSString *)secretAccessKey completionHandler:(S3CompletionHandler)completionHandler
{
	S3Connection *s3connection;
	s3connection = [[[S3Connection alloc] initWithAccessKeyId:accessKeyId secretAccessKey:secretAccessKey] autorelease];
	s3connection.bucket = bucket;
	[s3connection uploadFile:path withKey:key options:options completionHandler:completionHandler];
}

#pragma mark - NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	_statusCode = [(NSHTTPURLResponse *)response statusCode];
	if(_statusCode != 200)
		_responseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if(_responseData)
		[_responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	_connection = nil;
	if(_responseData)
	{
		[_responseData release];
		_responseData = nil;
	}
	if(_completionHandler)
		_completionHandler(error);
	[self release];
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
	return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	_connection = nil;
	if(_statusCode != 200)
	{
		NSString *message = nil;
		NSString *response = [[[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding] autorelease];
		NSRange start, end;
		start = [response rangeOfString:@"<message>" options:NSCaseInsensitiveSearch];
		end = [response rangeOfString:@"</message>" options:NSCaseInsensitiveSearch];
		if(start.location != NSNotFound && end.location != NSNotFound)
			message = [response substringWithRange:NSMakeRange(start.location + start.length, end.location - (start.location + start.length))];
		[_responseData release];
		_responseData = nil;
		if(_completionHandler)
			_completionHandler([NSError errorWithDomain:ERROR_DOMAIN_S3CONNECTION code:_statusCode userInfo:@{NSLocalizedDescriptionKey:message?message:STRING_S3_HTTPERROR}]);
	}
	else if(_completionHandler)
	{
		_completionHandler(nil);
	}
	[self release];
}

@end
