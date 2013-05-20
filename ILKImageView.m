//
//  ILKImageView.m
//  ImageLoader
//
//  Created by James Diomede on 5/1/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import "ILKImageView.h"

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
        cancelled = NO;
        self.error = NULL;
        self.urlString = urlString;
        self.response = [NSMutableData data];
        state = ILKImageDownloadStateInitialized;
    }
    return self;
}

- (void)start
{
    if (!cancelled) {
        [self willChangeValueForKey:@"isExecuting"];
        state = ILKImageDownloadStateExecuting;
        [self didChangeValueForKey:@"isExecuting"];
        NSURL *url = [NSURL URLWithString:self.urlString];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        //NSLog(@"Launch image download: %@ from thread: %@", self, [NSThread currentThread]);
        _startDownload = [[NSDate date] timeIntervalSince1970];
        [NSURLConnection connectionWithRequest:request delegate:self];
        [[NSRunLoop currentRunLoop] run];
    } else {
        self.error = [NSError errorWithDomain:NSOSStatusErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
        [self end];
    }
}

- (void)cancel
{
    //NSLog(@"%@ is cancelled", self);
    [self willChangeValueForKey:@"isCancelled"];
    cancelled = YES;
    [self didChangeValueForKey:@"isCancelled"];
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
- (BOOL)isCancelled     { return cancelled; }
- (BOOL)isExecuting     { return (state == ILKImageDownloadStateExecuting); }
- (BOOL)isFinished      { return (state == ILKImageDownloadStateFinished); }

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (!cancelled) {
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
    if (!cancelled) {
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
        _decodedImage = NULL;
        self.urlString = urlString;
        observerCount = 0;
    }
    return self;
}

- (void)cancel
{
    //NSLog(@"%@ is cancelled", self);
    [self willChangeValueForKey:@"isCancelled"];
    cancelled = YES;
    for (id operation in [self dependencies]) {
        if ([operation isKindOfClass:[ILKImageDownload class]]) {
            ILKImageDownload *downloadOperation = operation;
            [downloadOperation cancel];
        }
        else if ([operation isKindOfClass:[ILKImageDecode class]]) {
            ILKImageDecode *decodeOperation = operation;
            if ([[ILKImageView currentListeners] objectForKey:self.urlString] == NULL) {
                [[ILKImageView currentOperations] removeObjectForKey:decodeOperation.urlString];
                [decodeOperation cancel];
            }
        }
    }
    [self didChangeValueForKey:@"isCancelled"];
}

- (BOOL)isCancelled { return cancelled; }

- (void)main
{
    ILKImageDownload *downloadOperation = nil;
    BOOL downloadOperationWasSuccessful = NO;
    for (id operation in [self dependencies]) {
        if ([operation isKindOfClass:[ILKImageDownload class]]) {
            downloadOperation = operation;
            if (!downloadOperation.isCancelled &&
                downloadOperation.error == NULL &&
                downloadOperation.response != NULL) {
                downloadOperationWasSuccessful = YES;
            }
        }
    }
    if (!cancelled && downloadOperationWasSuccessful) {
        //NSLog(@"Launch image decode: %@ from thread: %@", self, [NSThread currentThread]);
        self.decodedImage = [UIImage imageWithData:imageData];
        //NSLog(@"%f", [[NSDate date] timeIntervalSince1970] - [downloadOperation startDownload]);
        [ILKImageView imageForUrlDidFinishLoading:_urlString fromOperation:self];
    }
}

@end

@implementation ILKImageView

static NSCache *imageCache = NULL;
static NSOperationQueue *downloadOperationQueue = NULL;
static NSOperationQueue *decodeOperationQueue = NULL;
static NSMutableDictionary *preloadOperations = NULL;
static NSMutableDictionary *currentOperations = NULL;
static NSMutableDictionary *currentListeners = NULL;
static NSLock *imageViewLock = NULL;

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
            [downloadOperationQueue setMaxConcurrentOperationCount:5];
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
            //[decodeOperationQueue setMaxConcurrentOperationCount:2];
        });
    }
    return decodeOperationQueue;
}

+ (NSMutableDictionary*)preloadOperations
{
    if (preloadOperations == NULL) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            preloadOperations = [[NSMutableDictionary alloc] init];
        });
    }
    return preloadOperations;
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

+ (NSMutableDictionary*)currentListeners
{
    if (currentListeners == NULL) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            currentListeners = [[NSMutableDictionary alloc] init];
        });
    }
    return currentListeners;
}

+ (NSLock*)imageViewLock
{
    if (imageViewLock == NULL) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            imageViewLock = [[NSLock alloc] init];
        });
    }
    return imageViewLock;
}

+ (void)imageForUrlDidFinishLoading:(NSString*)urlString fromOperation:(ILKImageDecode*)operation
{
    [[[self class] imageViewLock] lock];
    [[[self class] imageCache] setObject:operation.decodedImage forKey:operation.urlString];
    NSSet *listeners = [[[self class] currentListeners] objectForKey:urlString];
    for (ILKImageView *imageView in [listeners allObjects]) {
        [imageView observeValueForKeyPath:@"isFinished" ofObject:operation change:nil context:nil];
    }
    [[[self class] currentOperations] removeObjectForKey:urlString];
    [[[self class] imageViewLock] unlock];
}

+ (void)preloadImageForUrl:(NSString*)urlString referenceUrlString:(NSString*)referenceUrlString
{
    [[[self class] imageViewLock] lock];
    if ([[[self class] imageCache] objectForKey:urlString] == NULL) {
        ILKImageDecode *decodeOperation = [[[self class] currentOperations] objectForKey:urlString];
        if (decodeOperation == NULL) {
            ILKImageDownload *downloadOperation = [[[ILKImageDownload alloc] initWithUrlString:urlString] autorelease];
            if (downloadOperation != NULL) {
                decodeOperation = [[[ILKImageDecode alloc] initWithImageData:downloadOperation.response forUrlString:urlString] autorelease];
            }
            if (decodeOperation != NULL) {
                //NSLog(@"Queue download operation, current download queue count: %d", [[[self class] downloadOperationQueue] operationCount]);
                [downloadOperation setQueuePriority:NSOperationQueuePriorityLow];
                [[[self class] downloadOperationQueue] addOperation:downloadOperation];
                [decodeOperation setQueuePriority:NSOperationQueuePriorityLow];
                [decodeOperation addDependency:downloadOperation];
                ILKImageDecode *referenceDecodeOperation = [[ILKImageView currentOperations] objectForKey:referenceUrlString];
                if (referenceDecodeOperation != NULL) {
                    [decodeOperation addDependency:referenceDecodeOperation];
                }
                [[[self class] decodeOperationQueue] addOperation:decodeOperation];
            }
            [[[self class] currentOperations] setValue:decodeOperation forKey:urlString];
        }
    }
    [[[self class] imageViewLock] unlock];
}

+ (void)addImageView:(ILKImageView*)imageView forUrl:(NSString*)urlString
{
    [[[self class] imageViewLock] lock];
    ILKImageDecode *decodeOperation = [[[self class] currentOperations] objectForKey:urlString];
    if (decodeOperation == NULL) {
        ILKImageDownload *downloadOperation = [[[ILKImageDownload alloc] initWithUrlString:urlString] autorelease];
        if (downloadOperation != NULL) {
            decodeOperation = [[[ILKImageDecode alloc] initWithImageData:downloadOperation.response forUrlString:urlString] autorelease];
        }
        if (decodeOperation != NULL) {
            //NSLog(@"Queue download operation, current download queue count: %d", [[[self class] downloadOperationQueue] operationCount]);
            //[downloadOperation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
            [[[self class] downloadOperationQueue] addOperation:downloadOperation];
            //[decodeOperation addObserver:imageView forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
            [decodeOperation addDependency:downloadOperation];
            [[[self class] decodeOperationQueue] addOperation:decodeOperation];
        }
        [[[self class] currentOperations] setValue:decodeOperation forKey:urlString];
    } else {
        for (id operation in [decodeOperation dependencies]) {
            if ([operation isKindOfClass:[ILKImageDownload class]]) {
                ILKImageDownload *downloadOperation = operation;
                [downloadOperation setQueuePriority:NSOperationQueuePriorityNormal];
            }
        }
        [decodeOperation setQueuePriority:NSOperationQueuePriorityNormal];
        //[decodeOperation addObserver:imageView forKeyPath:urlString options:NSKeyValueObservingOptionNew context:nil];
    }
    NSMutableSet *listeners = [[[self class] currentListeners] objectForKey:urlString];
    if (listeners != NULL) {
        [listeners addObject:imageView];
    } else {
        listeners = [NSMutableSet setWithObject:imageView];
    }
    [[[self class] currentListeners] setObject:listeners forKey:urlString];
    [[[self class] imageViewLock] unlock];
}

+ (void)removeImageView:(ILKImageView*)imageView forUrl:(NSString*)urlString
{
    [[[self class] imageViewLock] lock];
    NSMutableSet *listeners = [[[self class] currentListeners] objectForKey:urlString];
    if (listeners != NULL) {
        [listeners removeObject:imageView];
        if ([listeners count] == 0) {
            [[[self class] currentListeners] removeObjectForKey:urlString];
            ILKImageDecode *operation = [[[self class] currentOperations] objectForKey:urlString];
            if (operation != NULL) {
                [operation cancel];
            }
            [[[self class] currentOperations] removeObjectForKey:urlString];
        } else {
            [[[self class] currentListeners] setObject:listeners forKey:urlString];
        }
    }
    [[[self class] imageViewLock] unlock];
}

- (void)dealloc
{
    [_urlString release];
    [super dealloc];
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
    if (_urlString) {
        [[self class] removeImageView:self forUrl:_urlString];
        [_urlString autorelease];
        _urlString = NULL;
    }
    _urlString = [urlString copy];
    if (_urlString != NULL) {
        UIImage *cachedImage = [[[self class] imageCache] objectForKey:_urlString];
        if (cachedImage != NULL) {
            self.image = cachedImage;
        } else {
            [[self class] addImageView:self forUrl:_urlString];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([object isKindOfClass:[ILKImageDecode class]]) {
        ILKImageDecode *operation = object;
        //[operation removeObserver:self forKeyPath:@"isFinished"];
        if ([_urlString isEqualToString:operation.urlString]) {
            [self didFinishDecodingImage:operation.decodedImage forUrl:operation.urlString];
        }
    }
}

- (void)didFinishDecodingImage:(UIImage *)decodedImage forUrl:(NSString*)urlString
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"Load image from main thread: %@", [NSThread currentThread]);
        [self setAlpha:0.0f];
        self.image = decodedImage;
        [UIView animateWithDuration:0.5f animations:^{
            [self setAlpha:1.0f];
        }];
        //[[self class] removeImageView:self forUrl:urlString];
    });
}

@end
