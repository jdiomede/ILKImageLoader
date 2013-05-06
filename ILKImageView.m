//
//  ILKImageView.m
//  ImageLoader
//
//  Created by James Diomede on 5/1/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

/* TODOs:   (1) optimize different operation queues for type
            (2) convert UIImage to CGImage and associated decode operations
            (3) handle failure to download and/or decode image with retries
            (4) expose cancel image download/decode on ILKImageView
 */

#import "ILKImageView.h"

@implementation ILKImageDecode

- (void)dealloc
{
    [imageData release];
    [_urlString release];
    [_decodedImage release];
    [super dealloc];
}

- (id)initWithImageData:(NSData *)initImageData forUrlString:(NSString*)urlString
{
    self = [super init];
    if (self) {
        imageData = [initImageData retain];
        self.urlString = urlString;
    }
    return self;
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
    observerCount++;
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context
{
    [super removeObserver:observer forKeyPath:keyPath context:context];
    observerCount--;
    if (observerCount == 0) {
        [[ILKImageView currentOperations] removeObjectForKey:self.urlString];
        //cancel
    }
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
    [super removeObserver:observer forKeyPath:keyPath];
    observerCount--;
    if (observerCount == 0) {
        [[ILKImageView currentOperations] removeObjectForKey:self.urlString];
        //cancel
    }
}

- (void)main
{
    //NSLog(@"Launch image decode: %@ from thread: %@", self, [NSThread currentThread]);
    [[ILKImageView currentOperations] setValue:self forKey:self.urlString];
    self.decodedImage = [UIImage imageWithData:imageData];
    [[ILKImageView currentOperations] removeObjectForKey:self.urlString];
}

@end

@implementation ILKImageDownload

- (void)dealloc
{
    [_urlString release];
    [_error release];
    [_response release];
    [super dealloc];
}

- (id)initWithUrlString:(NSString*)urlString
{
    self = [super init];
    if (self) {
        self.urlString = urlString;
        self.error = NULL;
        self.response = [NSMutableData data];
        state = ILKImageDownloadStateInitialized;
    }
    return self;
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
    observerCount++;
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context
{
    [super removeObserver:observer forKeyPath:keyPath context:context];
    observerCount--;
    if (observerCount == 0) {
        [[ILKImageView currentOperations] removeObjectForKey:self.urlString];
        [self cancel];
    }
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
    [super removeObserver:observer forKeyPath:keyPath];
    observerCount--;
    if (observerCount == 0) {
        [[ILKImageView currentOperations] removeObjectForKey:self.urlString];
        [self cancel];
    }
}

- (void)start
{
    if (state != ILKImageDownloadStateCancelled) {
        [self willChangeValueForKey:@"isExecuting"];
        state = ILKImageDownloadStateExecuting;
        [self didChangeValueForKey:@"isExecuting"];
        [[ILKImageView currentOperations] setValue:self forKey:self.urlString];
        NSURL *url = [NSURL URLWithString:self.urlString];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        if (connection == NULL) {
            self.error = [NSError errorWithDomain:NSOSStatusErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
            [self end];
        } else {
            //NSLog(@"Launch image download: %@ from thread: %@", self, [NSThread currentThread]);
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [connection scheduleInRunLoop:runLoop forMode:NSRunLoopCommonModes];
            [connection start];
            [runLoop run];
        }
    } else {
        self.error = [NSError errorWithDomain:NSOSStatusErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
        [self end];
    }
}

- (void)cancel
{
    //NSLog(@"%@ is cancelled", self);
    [self willChangeValueForKey:@"isCancelled"];
    state = ILKImageDownloadStateCancelled;
    [self didChangeValueForKey:@"isCancelled"];
}

- (void)end
{
    [[ILKImageView currentOperations] removeObjectForKey:self.urlString];
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    state = ILKImageDownloadStateFinished;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isConcurrent    { return YES; }
- (BOOL)isExecuting     { return (state == ILKImageDownloadStateExecuting); }
- (BOOL)isCancelled     { return (state == ILKImageDownloadStateCancelled); }
- (BOOL)isFinished      { return (state == ILKImageDownloadStateFinished); }

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (state != ILKImageDownloadStateCancelled) {
        self.status = ((NSHTTPURLResponse*)response).statusCode;
        [self.response setLength:0];
    } else {
        [connection cancel];
        self.error = [NSError errorWithDomain:NSOSStatusErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
        [self end];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error = error;
    [self end];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (state != ILKImageDownloadStateCancelled) {
        //NSLog(@"Append image data from thread: %@", [NSThread currentThread]);
        [self.response appendData:data];
    } else {
        [connection cancel];
        self.error = [NSError errorWithDomain:NSOSStatusErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
        [self end];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self end];
}

@end

@implementation ILKImageView

static NSCache *imageCache = NULL;
static NSOperationQueue *downloadOperationQueue = NULL;
static NSOperationQueue *decodeOperationQueue = NULL;
static NSMutableDictionary *currentOperations = NULL;
static NSLock *lockCurrentOperations = NULL;

+ (NSCache*)imageCache
{
    if (imageCache == NULL) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            imageCache = [[NSCache alloc] init];
        });
    }
    return imageCache;
}

+ (NSOperationQueue*)downloadOperationQueue
{
    if (downloadOperationQueue == NULL) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            downloadOperationQueue = [[NSOperationQueue alloc] init];
            [downloadOperationQueue setMaxConcurrentOperationCount:10];
        });
    }
    return downloadOperationQueue;
}

+ (NSOperationQueue*)decodeOperationQueue
{
    if (decodeOperationQueue == NULL) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            decodeOperationQueue = [[NSOperationQueue alloc] init];
            [decodeOperationQueue setMaxConcurrentOperationCount:25];
        });
    }
    return decodeOperationQueue;
}

+ (NSMutableDictionary*)currentOperations
{
    if (currentOperations == NULL) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            currentOperations = [[NSMutableDictionary alloc] init];
        });
    }
    return currentOperations;
}

+ (NSLock*)lockCurrentOperations
{
    if (lockCurrentOperations == NULL) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            lockCurrentOperations = [[NSLock alloc] init];
        });
    }
    return lockCurrentOperations;
}

- (id)initWithFrame:(CGRect)frame forUrlString:(NSString*)urlString
{
    self = [super initWithFrame:frame];
    if (self) {
        self.urlString = urlString;
    }
    return self;
}

- (void)setUrlString:(NSString *)urlString
{
    [[[self class] lockCurrentOperations] lock];
    BOOL queueDownloadOperation = NO;
    if (![_urlString isEqualToString:urlString]) {
        if (_urlString != NULL) {
            NSOperation *operation = [[[self class] currentOperations] valueForKey:_urlString];
            if (operation != NULL) {
                //[[[self class] currentOperations] removeObjectForKey:_urlString];
                [operation removeObserver:self forKeyPath:@"isFinished"];
                //[operation cancel];
            }
            [_urlString autorelease];
            _urlString = NULL;
        }
        _urlString = [urlString copy];
        if (_urlString != NULL) {
            UIImage *cachedImage = [[[self class] imageCache] objectForKey:_urlString];
            if (cachedImage != NULL) {
                self.image = cachedImage;
            } else {
                NSOperation *operation = [[[self class] currentOperations] objectForKey:_urlString];
                if (operation == NULL) {
                    queueDownloadOperation = YES;
                } else {
                    [operation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
                }
            }
            
        }
    } else if ([[[self class] imageCache] objectForKey:_urlString] != NULL) {
        self.image = [[[self class] imageCache] objectForKey:_urlString];
    } else if ([[[self class] currentOperations] objectForKey:_urlString] != NULL) {
        NSOperation *operation = [[[self class] currentOperations] objectForKey:_urlString];
        [operation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
    } else {
        queueDownloadOperation = YES;
    }
    if (queueDownloadOperation) {
        ILKImageDownload *downloadOperation = [[[ILKImageDownload alloc] initWithUrlString:_urlString] autorelease];
        if (downloadOperation != NULL) {
            [downloadOperation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
            //[[[self class] currentOperations] setValue:downloadOperation forKey:_urlString];
            //NSLog(@"Queue download operation, current download queue count: %d, cached image: %@", [[[self class] downloadOperationQueue] operationCount], [[[self class] imageCache] objectForKey:_urlString]);
            [[[self class] downloadOperationQueue] addOperation:downloadOperation];
        }
    }
    [[[self class] lockCurrentOperations] unlock];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [[[self class] lockCurrentOperations] lock];
    if ([object isKindOfClass:[ILKImageDownload class]]) {
        ILKImageDownload *downloadOperation = object;
        //[[[self class] currentOperations] removeObjectForKey:downloadOperation.urlString];
        [downloadOperation removeObserver:self forKeyPath:@"isFinished"];
        if (downloadOperation.error == NULL &&
            downloadOperation.response != NULL &&
            [self.urlString isEqualToString:downloadOperation.urlString] &&
            [[[self class] currentOperations] objectForKey:downloadOperation.urlString] == NULL) {
            ILKImageDecode *decodeOperation = [[[ILKImageDecode alloc] initWithImageData:downloadOperation.response forUrlString:downloadOperation.urlString] autorelease];
            if (decodeOperation != NULL) {
                [decodeOperation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
                //[[[self class] currentOperations] setValue:decodeOperation forKey:decodeOperation.urlString];
                [[[self class] decodeOperationQueue] addOperation:decodeOperation];
            }
        } else if (downloadOperation.error != NULL) {
            NSLog(@"Download operation failed with error: %@", downloadOperation.error);
        }
    }
    else if ([object isKindOfClass:[ILKImageDecode class]]) {
        ILKImageDecode *decodeOperation = object;
        //[[[self class] currentOperations] removeObjectForKey:decodeOperation.urlString];
        [decodeOperation removeObserver:self forKeyPath:@"isFinished"];
        if ([self.urlString isEqualToString:decodeOperation.urlString]) {
            UIImage *decodedImage = [[[self class] imageCache] objectForKey:decodeOperation.urlString];
            if (decodedImage == NULL) {
                [[[self class] imageCache] setObject:decodeOperation.decodedImage forKey:decodeOperation.urlString];
                [self didFinishDecodingImage:decodeOperation.decodedImage];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.image = decodedImage;
                });
            }
        }
    }
    [[[self class] lockCurrentOperations] unlock];
}

- (void)didFinishDecodingImage:(UIImage *)decodedImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"Load image from main thread: %@", [NSThread currentThread]);
        [self setAlpha:0.0f];
        self.image = decodedImage;
        [UIView animateWithDuration:1.0f animations:^{
            [self setAlpha:1.0f];
        }];
    });
}

@end
