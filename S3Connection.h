//
//  S3Connection.h
//
//  Copyright 2014 Symbiotic Software. All rights reserved.
//
//  A simple S3 class to upload files. Be sure to also link with CommonCrypto, MobileCoreServices, and compile with NSData+Encoding.
//  Optionally, gzip data and files using NSData+gzip and the Content-Encoding: gzip header will be added with the S3_DETECT_GZIP option.
//

#import <Foundation/Foundation.h>

#define S3_DETECT_GZIP			(1<<0)
#define S3_NO_CACHE				(1<<1)
#define S3_PERMANENT_CACHE		(1<<2)
#define S3_REDUCED_REDUNDANCY	(1<<3)
#define S3_HTTPS				(1<<4)

#define ERROR_DOMAIN_S3CONNECTION @"com.symbioticsoftware.S3Connection"

typedef void (^S3CompletionHandler)(NSError *);

@interface S3Connection : NSObject

@property (nonatomic, copy) NSString *accessKeyId;
@property (nonatomic, copy) NSString *secretAccessKey;
@property (nonatomic, copy) NSString *bucket;
@property (nonatomic, retain) NSDictionary *extraHeaders;

- (id)initWithAccessKeyId:(NSString *)accessKeyId secretAccessKey:(NSString *)secretAccessKey;
- (void)cancelCurrentRequest;

- (void)uploadData:(NSData *)data
           withKey:(NSString *)key
       contentType:(NSString *)contentType
           options:(NSUInteger)options
 completionHandler:(S3CompletionHandler)completionHandler;

- (void)uploadFile:(NSString *)path
           withKey:(NSString *)key
           options:(NSUInteger)options
 completionHandler:(S3CompletionHandler)completionHandler;

+ (void)uploadData:(NSData *)data
		intoBucket:(NSString *)bucket
		   withKey:(NSString *)key
	   contentType:(NSString *)contentType
           options:(NSUInteger)options
	   accessKeyId:(NSString *)accessKeyId
   secretAccessKey:(NSString *)secretAccessKey
 completionHandler:(S3CompletionHandler)completionHandler;

+ (void)uploadFile:(NSString *)path
		intoBucket:(NSString *)bucket
		   withKey:(NSString *)key
           options:(NSUInteger)options
	   accessKeyId:(NSString *)accessKeyId
   secretAccessKey:(NSString *)secretAccessKey
 completionHandler:(S3CompletionHandler)completionHandler;

@end
