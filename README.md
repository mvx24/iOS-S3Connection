S3Connection
-------------------------------

S3Connection is a simple connection class for uploading files and data to an Amazon S3 bucket.

## S3Connection Reference

#### Completion Handler

`typedef void (^S3CompletionHandler)(NSError *)`

The completion handler will be called when the upload has completed successfully or has failed. NSError will be set to an NSError object on failure and nil upon success.

#### Uploading a File

```Obj-C
+ (void)uploadFile:(NSString *)path
		intoBucket:(NSString *)bucket
		   withKey:(NSString *)key
           options:(NSUInteger)options
	   accessKeyId:(NSString *)accessKeyId
   secretAccessKey:(NSString *)secretAccessKey
 completionHandler:(S3CompletionHandler)completionHandler;
```

* `path` - the path to the file on disk
* `bucket` - the bucket to upload to
* `key` - the remote path/file name you wish to upload to in the bucket
* `options` - bit flag options for setting some additional headers
* `accessKeyId` - your Amazon S3 access key id
* `secretAccessKey` - your secret Amazon S3 access key
* `completionHandler` - a completion block that gets called when the upload has completed

#### Uploading Data

```Obj-C
+ (void)uploadData:(NSData *)data
		intoBucket:(NSString *)bucket
		   withKey:(NSString *)key
	   contentType:(NSString *)contentType
           options:(NSUInteger)options
	   accessKeyId:(NSString *)accessKeyId
   secretAccessKey:(NSString *)secretAccessKey
 completionHandler:(S3CompletionHandler)completionHandler;
```

The method for uploading data is exactly the same as the file, only that contentType is expected because the MIME type cannot be detected as easily like it can with a file.

**NOTE** - Keys shouldn't begin with a `/`. If they do, S3Connection will automatically remove it.

#### GZIP Data

Files and data encoded with gzip will be detected automatically by S3Connection with the `S3_DETECT_GZIP` option and the appropriate Content-Encoding: gzip header will be added. Use NSData+gzip to deflate data, found here: <https://github.com/mvx24/NSData-Encoding>

**NOTE** - Image files shouldn't be gzipped, because most have their own image compression already.

#### Options

Below is a list of options and their purpose.

* `S3_DETECT_GZIP` - will automatically detect if the data or file is gzip be looking for a magic number and adding the appropriate Content-Encoding as a result
* `S3_NO_CACHE` - sets the Cache-Control header to no-cache for files that are likely to change
* `S3_PERMANENT_CACHE` - sets the Cache-Control header to max-age=315360000 for files that are intended to be permanent
* `S3_REDUCED_REDUNDANCY` - sets the file to be stored using the cheaper reduced redundancy storage
* `S3_HTTPS` - connect to S3 using HTTPS instead of HTTP - using either methods, the secret access key is never sent as part of the request but the access key id is

#### Custom Headers

To add additional headers not available through the provided options, don't use the class-based methods above, create an S3Connection with the normal alloc/init and set the extraHeaders property. Using this you can set your own Cache-Control, or add key-value user data on the object with x-amz-meta- headers etc..

To view all headers can be used visit: <http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html>

## Security

It is recommended that you obfuscate your secret access key as much as possible before compiling it into your source code and then deobfuscating at runtime.

## Dependencies

You must add and link with the following frameworks: CommonCrypto (MD5 hashing), MobileCoreServices (MIME type detection). Additionally, S3Connection relies on an NSData+Encoding category for performing base64 encoding when creating the request signature. You can find the NSData+Encoding category on github here: <https://github.com/mvx24/NSData-Encoding>

## ARC

These files do not use ARC, if your project is using ARC be sure to add the -fno-objc-arc compiler flags to build phases of these files.

## License

The BSD License
