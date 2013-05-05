//
//  ILKImageView.m
//  ImageLoader
//
//  Created by James Diomede on 5/1/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import "ILKImageView.h"

@implementation ILKImageDecode

- (void)dealloc
{
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

- (void)main
{
    self.decodedImage = [UIImage imageWithData:imageData];
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
        self.error = nil;
        self.response = [NSMutableData data];
        state = ILKImageDownloadStateInitialized;
    }
    return self;
}

- (void)start
{
    [self willChangeValueForKey:@"isExecuting"];
    state = ILKImageDownloadStateExecuting;
    [self didChangeValueForKey:@"isExecuting"];
    NSURL *url = [NSURL URLWithString:self.urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (connection == nil) {
        self.error = [NSError errorWithDomain:NSOSStatusErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
        [self end];
    } else {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [connection scheduleInRunLoop:runLoop forMode:NSRunLoopCommonModes];
        [connection start];
        [runLoop run];
    }
}

- (void)end
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    state = ILKImageDownloadStateFinished;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isConcurrent    { return YES; }
- (BOOL)isExecuting     { return (state == ILKImageDownloadStateExecuting); }
- (BOOL)isFinished      { return (state == ILKImageDownloadStateFinished); }

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.status = ((NSHTTPURLResponse*)response).statusCode;
    [self.response setLength:0];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error = error;
    [self end];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.response appendData:data];
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
    if (_urlString) {
        NSOperation *operation = [[[self class] currentOperations] valueForKey:_urlString];
        if (operation) {
            [[[self class] currentOperations] removeObjectForKey:_urlString];
            [operation removeObserver:self forKeyPath:@"isFinished"];
            [operation cancel];
        }
        [_urlString autorelease];
        _urlString = NULL;
    }
    _urlString = [urlString copy];
    if (_urlString) {
        UIImage *cachedImage = [[[self class] imageCache] objectForKey:_urlString];
        if (cachedImage != NULL) {
            self.image = cachedImage;
        } else if ([[[self class] currentOperations] objectForKey:_urlString] == NULL) {
            ILKImageDownload *downloadOperation = [[[ILKImageDownload alloc] initWithUrlString:_urlString] autorelease];
            if (downloadOperation != NULL) {
                [downloadOperation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
                [[[self class] currentOperations] setValue:downloadOperation forKey:_urlString];
                [[[self class] downloadOperationQueue] addOperation:downloadOperation];
            }
        }
    }
    [[[self class] lockCurrentOperations] unlock];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [[ILKImageView lockCurrentOperations] lock];
    if ([object isKindOfClass:[ILKImageDownload class]]) {
        ILKImageDownload *downloadOperation = object;
        [[[self class] currentOperations] removeObjectForKey:downloadOperation.urlString];
        [downloadOperation removeObserver:self forKeyPath:@"isFinished"];
        if (!downloadOperation.error && downloadOperation.response) {
            ILKImageDecode *decodeOperation = [[[ILKImageDecode alloc] initWithImageData:downloadOperation.response forUrlString:downloadOperation.urlString] autorelease];
            if (decodeOperation) {
                [decodeOperation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
                [[[self class] currentOperations] setValue:decodeOperation forKey:decodeOperation.urlString];
                [[[self class] decodeOperationQueue] addOperation:decodeOperation];
            }
        } else {
            NSLog(@"Download operation failed with error: %@", downloadOperation.error);
        }
    }
    else if ([object isKindOfClass:[ILKImageDecode class]]) {
        ILKImageDecode *decodeOperation = object;
        [[[self class] currentOperations] removeObjectForKey:decodeOperation.urlString];
        [decodeOperation removeObserver:self forKeyPath:@"isFinished"];
        [[[self class] imageCache] setObject:decodeOperation.decodedImage forKey:decodeOperation.urlString];
        [self didFinishDecodingImage:decodeOperation.decodedImage];
    }
    [[ILKImageView lockCurrentOperations] unlock];
}

- (void)didFinishDecodingImage:(UIImage *)decodedImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setAlpha:0.0f];
        self.image = decodedImage;
        [UIView animateWithDuration:1.0f animations:^{
            [self setAlpha:1.0f];
        }];
    });
}

@end
