//
//  CustomImageView.m
//  ImageLoader
//
//  Created by James Diomede on 5/1/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import "CustomImageView.h"

@implementation CustomImageDecode

- (void)dealloc
{
    [_urlString release];
    [_decodedImage release];
    [super dealloc];
}

- (id)initWithImageData:(NSData *)initImageData forURLString:(NSString*)initURLString
{
    self = [super init];
    if (self) {
        imageData = [initImageData retain];
        self.urlString = initURLString;
    }
    return self;
}

- (void)main
{
    NSLog(@"Run custom image decode from thread: %@", [NSThread currentThread]);
    self.decodedImage = [UIImage imageWithData:imageData];
}

@end

@implementation CustomImageDownload

- (void)dealloc
{
    [_urlString release];
    [_error release];
    [_response release];
    [super dealloc];
}

- (id)initWithURLString:(NSString*)initURLString
{
    self = [super init];
    if (self) {
        self.urlString = initURLString;
        self.error = nil;
        self.response = [NSMutableData data];
        state = CustomImageDownloadStateInitialized;
    }
    return self;
}

- (void)start
{
    NSLog(@"Start custom image download from thread: %@", [NSThread currentThread]);
    [self willChangeValueForKey:@"isExecuting"];
    state = CustomImageDownloadStateExecuting;
    [self didChangeValueForKey:@"isExecuting"];
    NSURL *url = [NSURL URLWithString:self.urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (connection == nil) {
        self.error = [NSError errorWithDomain:NSOSStatusErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
        [self willChangeValueForKey:@"isFinished"];
        state = CustomImageDownloadStateFinished;
        [self didChangeValueForKey:@"isFinised"];
    } else {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [connection scheduleInRunLoop:runLoop forMode:NSRunLoopCommonModes];
        [connection start];
        [runLoop run];
    }
}

- (BOOL)isConcurrent    { return YES; }
- (BOOL)isExecuting     { return (state == CustomImageDownloadStateExecuting); }
- (BOOL)isFinished      { return (state == CustomImageDownloadStateFinished); }

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.status = ((NSHTTPURLResponse*)response).statusCode;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error = error;
    [self willChangeValueForKey:@"isFinished"];
    state = CustomImageDownloadStateFinished;
    [self didChangeValueForKey:@"isFinised"];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSLog(@"Append custom image data from thread: %@", [NSThread currentThread]);
    [self.response appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self willChangeValueForKey:@"isFinished"];
    state = CustomImageDownloadStateFinished;
    [self didChangeValueForKey:@"isFinished"];
}

@end

@implementation CustomImageView

static NSCache *imageCache = nil;
static NSOperationQueue *operationQueue = nil;

+(NSCache*)imageCache
{
    if (!imageCache) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            imageCache = [[[NSCache alloc] init] retain];
        });
    }
    return imageCache;
}

+ (NSOperationQueue*)operationQueue
{
    if (!operationQueue) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            operationQueue = [[[NSOperationQueue alloc] init] retain];
        });
    }
    return operationQueue;
}

- (id)initWithFrame:(CGRect)frame forURLString:(NSString*)initURLString
{
    self = [super initWithFrame:frame];
    if (self) {
        if ([[[self class] imageCache] objectForKey:initURLString]) {
            NSLog(@"This image is cached.");
        } else {
            CustomImageDownload *downloadOperation = [[[CustomImageDownload alloc] initWithURLString:initURLString] autorelease];
            [downloadOperation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
            [[[self class] operationQueue] addOperation:downloadOperation];
        }
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([object isKindOfClass:[CustomImageDownload class]]) {
        CustomImageDownload *downloadOperation = object;
        [downloadOperation removeObserver:self forKeyPath:@"isFinished"];
        if (!downloadOperation.error && downloadOperation.response) {
            CustomImageDecode *decodeOperation = [[[CustomImageDecode alloc] initWithImageData:downloadOperation.response forURLString:downloadOperation.urlString] autorelease];
            [decodeOperation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
            [[[self class] operationQueue] addOperation:decodeOperation];
        }
    }
    else if ([object isKindOfClass:[CustomImageDecode class]]) {
        CustomImageDecode *decodeOperation = object;
        [decodeOperation removeObserver:self forKeyPath:@"isFinished"];
        [[[self class] imageCache] setObject:decodeOperation.decodedImage forKey:decodeOperation.urlString];
        [self didFinishDecodingImage:decodeOperation.decodedImage];
    }
}

- (void)didFinishDecodingImage:(UIImage *)decodedImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Load custom image from main thread: %@", [NSThread currentThread]);
        [self setAlpha:0.0f];
        self.image = decodedImage;
        [UIView animateWithDuration:1.0f animations:^{
            [self setAlpha:1.0f];
        }];
    });
}

@end
