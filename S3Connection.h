//
//  S3Connection.h
//
//  Copyright 2014 Symbiotic Software. All rights reserved.
//
//  A simple S3 class to upload files. Be sure to also link with CommonCrypto, MobileCoreServices, and compile with NSData+Encoding.
//  NOTE: When uploading, do not start keys with a /
//

#import <Foundation/Foundation.h>

#define ERROR_DOMAIN_S3CONNECTION @"com.symbioticsoftware.S3Connection"

typedef void (^S3CompletionHandler)(NSError *);

@interface S3Connection : NSObject

@property (nonatomic, copy) NSString *accessKeyId;
@property (nonatomic, copy) NSString *secretAccessKey;
@property (nonatomic, copy) NSString *bucket;

- (id)initWithAccessKeyId:(NSString *)accessKeyId secretAccessKey:(NSString *)secretAccessKey;
- (void)cancelCurrentRequest;
- (void)uploadData:(NSData *)data securely:(BOOL)securely withKey:(NSString *)key contentType:(NSString *)contentType completionHandler:(S3CompletionHandler)completionHandler;
- (void)uploadFile:(NSString *)path securely:(BOOL)securely withKey:(NSString *)key completionHandler:(S3CompletionHandler)completionHandler;

+ (void)uploadData:(NSData *)data
		  securely:(BOOL)securely
		intoBucket:(NSString *)bucket
		   withKey:(NSString *)key
	   contentType:(NSString *)contentType
	   accessKeyId:(NSString *)accessKeyId
   secretAccessKey:(NSString *)secretAccessKey
 completionHandler:(S3CompletionHandler)completionHandler;

+ (void)uploadFile:(NSString *)path
		  securely:(BOOL)securely
		intoBucket:(NSString *)bucket
		   withKey:(NSString *)key
	   accessKeyId:(NSString *)accessKeyId
   secretAccessKey:(NSString *)secretAccessKey
 completionHandler:(S3CompletionHandler)completionHandler;

@end
