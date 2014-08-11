S3Connection
-------------------------------

S3Connection is a simple connection class for uploading files and data to an Amazon S3 bucket.

## S3Connection Reference

#### Completion Handler

`typedef void (^S3CompletionHandler)(NSError *)`

The completion handler will be called when the upload has completed successfully or has failed. NSError will be set to an NSError object on failure and nil upon success.

#### Uploading a File

	+ (void)uploadFile:(NSString *)path
		securely:(BOOL)securely
		intoBucket:(NSString *)bucket
		withKey:(NSString *)key
		accessKeyId:(NSString *)accessKeyId
  		secretAccessKey:(NSString *)secretAccessKey
 		completionHandler:(S3CompletionHandler)completionHandler

* `path` - the path to the file on disk
* `securely` - indicates if you want to use https or not
* `bucket` - the bucket to upload to
* `key` - the remote path/file name you wish to upload to in the bucket
* `accessKeyId` - your Amazon S3 access key id
* `secretAccessKey` - your secret Amazon S3 access key
* `completionHandler` - a completion block that gets called when the upload has completed

#### Uploading Data

	+ (void)uploadData:(NSData *)data
		securely:(BOOL)securely
		intoBucket:(NSString *)bucket
		withKey:(NSString *)key
		contentType:(NSString *)contentType
		accessKeyId:(NSString *)accessKeyId
		secretAccessKey:(NSString *)secretAccessKey
		completionHandler:(S3CompletionHandler)completionHandler;

The method for uploading data is exactly the same as the file, only that contentType is expected because the MIME type cannot be detected as easily like it can with a file.

**NOTE** - Keys shouldn't begin with a `/`. If they do, S3Connection will automatically remove it.

## Security

It is recommended that you obfuscate your secret access key as much as possible before compiling it into your source code and then deobfuscating at runtime.

## Dependencies

You must add and link with the following frameworks: CommonCrypto (MD5 hashing), MobileCoreServices (MIME type detection). Additionally, S3Connection relies on an NSData+Encoding category for performing base64 encoding when creating the request signature. You can find the NSData+Encoding category on github here: <https://github.com/mvx24/NSData-Encoding>

## ARC

These files do not use ARC, if your project is using ARC be sure to add the -fno-objc-arc compiler flags to build phases of these files.

## License

The BSD License
