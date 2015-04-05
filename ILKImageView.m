//
//  ILKImageView.m
//  ImageLoader
//
//  Created by James Diomede on 5/1/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import "ILKImageView.h"

#import <CoreGraphics/CoreGraphics.h>

NSString *const ILKImageSizeAttributeName = @"ILKImageSizeAttribute";
NSString *const ILKViewContentModeAttributeName = @"ILKViewContentModeAttributeName";
NSString *const ILKCornerRadiusAttributeName = @"ILKCornerRadiusAttribute";
NSString *const ILKRectCornerAttributeName = @"ILKRectCornerAttribute";

enum {
  ILKImageDownloadStateInitialized,
  ILKImageDownloadStateExecuting,
  ILKImageDownloadStateFinished
};
typedef NSUInteger ILKImageDownloadState;

#pragma mark - ILKImageDownload

@interface ILKImageDownload : NSOperation <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
  BOOL cancelled;
  ILKImageDownloadState state;
}

@property (nonatomic, assign) NSTimeInterval startDownload;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, retain) NSError *error;
@property (nonatomic, retain) NSMutableData *response;

- (id)initWithUrlString:(NSString*)urlString;

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
        cancelled = NO;
        state = ILKImageDownloadStateInitialized;
        _error = nil;
        _urlString = [urlString copy];
        _response = [[NSMutableData alloc] init];
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

#pragma mark - ILKImageDecode

@interface ILKImageDecode : NSOperation {
  BOOL cancelled;
  NSData *imageData;
  NSUInteger observerCount;
}

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, retain) NSDictionary *attributes;
@property (nonatomic, retain) UIImage *processedImage;

- (id)initWithImageData:(NSData *)initImageData forUrlString:(NSString *)urlString withAttributes:(NSDictionary *)attributes;

@end

@implementation ILKImageDecode

- (void)dealloc
{
    [imageData release];
    [_urlString release];
    [_attributes release];
    [_processedImage release];
    [super dealloc];
}

- (id)initWithImageData:(NSData *)initImageData forUrlString:(NSString *)urlString withAttributes:(NSDictionary *)attributes
{
    self = [super init];
    if (self) {
        observerCount = 0;
        imageData = [initImageData retain];
        _processedImage = nil;
        _urlString = [urlString copy];
        _attributes = [attributes retain];
    }
    return self;
}

- (void)cancel
{
    [self willChangeValueForKey:@"isCancelled"];
    cancelled = YES;
    for (id operation in [self dependencies]) {
        if ([operation isKindOfClass:[ILKImageDownload class]]) {
            ILKImageDownload *downloadOperation = operation;
            [downloadOperation cancel];
        }
        else if ([operation isKindOfClass:[ILKImageDecode class]]) {
            ILKImageDecode *decodeOperation = operation;
            NSString *cacheKey = [ILKImageView cacheKeyForUrlString:decodeOperation.urlString withAttributes:decodeOperation.attributes];
            if ([[ILKImageView currentListeners] objectForKey:cacheKey] == nil) {
                [[ILKImageView currentOperations] removeObjectForKey:cacheKey];
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
                downloadOperation.error == nil &&
                downloadOperation.response != nil) {
                downloadOperationWasSuccessful = YES;
            }
        }
    }
    if (!cancelled && downloadOperationWasSuccessful) {
        UIImage *decodedImage = [UIImage imageWithData:imageData];
      
        CGSize imageSize = [self.attributes[ILKImageSizeAttributeName] CGSizeValue];
      
        CGRect drawRect = CGRectMake(0.0f, 0.0f, imageSize.width, imageSize.height);
        if ([self.attributes[ILKViewContentModeAttributeName] integerValue] == ILKViewContentModeScaleAspectFill) {
            CGFloat horizontalRatio = imageSize.width / CGImageGetWidth(decodedImage.CGImage);
            CGFloat verticalRatio = imageSize.height / CGImageGetHeight(decodedImage.CGImage);
            CGFloat ratio = MAX(horizontalRatio, verticalRatio);
            CGSize aspectFillSize = CGSizeMake(CGImageGetWidth(decodedImage.CGImage) * ratio, CGImageGetHeight(decodedImage.CGImage) * ratio);
            drawRect = CGRectMake((imageSize.width-aspectFillSize.width)/2.0f, (imageSize.height-aspectFillSize.height)/2.0f, aspectFillSize.width, aspectFillSize.height);
        }
      
        CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(decodedImage.CGImage);
        if ((bitmapInfo & kCGBitmapAlphaInfoMask) == kCGImageAlphaNoneSkipFirst) {
            bitmapInfo &= (!kCGBitmapAlphaInfoMask | kCGImageAlphaPremultipliedFirst);
        }
        else if ((bitmapInfo & kCGBitmapAlphaInfoMask) == kCGImageAlphaNoneSkipLast) {
            bitmapInfo &= (!kCGBitmapAlphaInfoMask | kCGImageAlphaPremultipliedLast);
        }
        else if ((bitmapInfo & kCGBitmapAlphaInfoMask) == kCGImageAlphaNone) {
            // TODO: add alpha channel to image data
        }
        CGContextRef context = CGBitmapContextCreate(nil, imageSize.width, imageSize.height, CGImageGetBitsPerComponent(decodedImage.CGImage), 0, CGImageGetColorSpace(decodedImage.CGImage), bitmapInfo);
      
        if ([self.attributes[ILKCornerRadiusAttributeName] floatValue] > 0.0f) {
            CGFloat scale = [UIScreen mainScreen].scale;
            CGFloat cornerRadius = [self.attributes[ILKCornerRadiusAttributeName] floatValue] * scale;
            ILKRectCorner corners = ILKRectCornerAllCorners;
            if (self.attributes[ILKRectCornerAttributeName] != nil) {
              corners = [self.attributes[ILKRectCornerAttributeName] integerValue];
            }
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.0f, 0.0f, imageSize.width, imageSize.height) byRoundingCorners:(UIRectCorner)corners cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
            CGContextAddPath(context, path.CGPath);
            CGContextEOClip(context);
        }

        CGContextDrawImage(context, drawRect, decodedImage.CGImage);
        CGImageRef cgImageRef = CGBitmapContextCreateImage(context);
        self.processedImage = [UIImage imageWithCGImage:cgImageRef];
        CGContextRelease(context);
        CGImageRelease(cgImageRef);
      
        NSString *cacheKey = [ILKImageView cacheKeyForUrlString:self.urlString withAttributes:self.attributes];
        [ILKImageView imageDidFinishLoadingForCacheKey:cacheKey fromOperation:self];
    }
}

@end

#pragma mark - ILKImageView

@implementation ILKImageView

static NSCache *imageCache = nil;
static NSOperationQueue *downloadOperationQueue = nil;
static NSOperationQueue *decodeOperationQueue = nil;
static NSMutableDictionary *currentOperations = nil;
static NSMutableDictionary *currentListeners = nil;
static NSLock *imageViewLock = nil;

+ (NSCache*)imageCache
{
    if (imageCache == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            imageCache = [[NSCache alloc] init];
        });
    }
    return imageCache;
}

+ (NSOperationQueue*)downloadOperationQueue
{
    if (downloadOperationQueue == nil) {
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
    if (decodeOperationQueue == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            decodeOperationQueue = [[NSOperationQueue alloc] init];
        });
    }
    return decodeOperationQueue;
}

+ (NSMutableDictionary*)currentOperations
{
    if (currentOperations == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            currentOperations = [[NSMutableDictionary alloc] init];
        });
    }
    return currentOperations;
}

+ (NSMutableDictionary*)currentListeners
{
    if (currentListeners == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            currentListeners = [[NSMutableDictionary alloc] init];
        });
    }
    return currentListeners;
}

+ (NSLock*)imageViewLock
{
    if (imageViewLock == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            imageViewLock = [[NSLock alloc] init];
        });
    }
    return imageViewLock;
}

+ (void)imageDidFinishLoadingForCacheKey:(NSString *)cacheKey fromOperation:(ILKImageDecode *)operation
{
    [[[self class] imageViewLock] lock];
    [[[self class] imageCache] setObject:operation.processedImage forKey:cacheKey];
    NSSet *listeners = [[[self class] currentListeners] objectForKey:cacheKey];
    for (ILKImageView *imageView in [listeners allObjects]) {
        [imageView observeValueForKeyPath:@"isFinished" ofObject:operation change:nil context:nil];
    }
    [[[self class] currentListeners] removeObjectForKey:cacheKey];
    [[[self class] currentOperations] removeObjectForKey:cacheKey];
    [[[self class] imageViewLock] unlock];
}

+ (void)addImageView:(ILKImageView*)imageView forUrlString:(NSString*)urlString withAttributes:(NSDictionary *)attributes
{
    [[[self class] imageViewLock] lock];
    NSString *cacheKey = [ILKImageView cacheKeyForUrlString:urlString withAttributes:attributes];
    ILKImageDecode *decodeOperation = [[[self class] currentOperations] objectForKey:cacheKey];
    if (decodeOperation == nil) {
        ILKImageDownload *downloadOperation = [[[ILKImageDownload alloc] initWithUrlString:urlString] autorelease];
        if (downloadOperation != nil) {
            decodeOperation = [[[ILKImageDecode alloc] initWithImageData:downloadOperation.response forUrlString:urlString withAttributes:attributes] autorelease];
        }
        if (decodeOperation != nil) {
            [[[self class] downloadOperationQueue] addOperation:downloadOperation];
            [decodeOperation addDependency:downloadOperation];
            [[[self class] decodeOperationQueue] addOperation:decodeOperation];
        }
        [[[self class] currentOperations] setValue:decodeOperation forKey:cacheKey];
    } else {
        for (id operation in [decodeOperation dependencies]) {
            if ([operation isKindOfClass:[ILKImageDownload class]]) {
                ILKImageDownload *downloadOperation = operation;
                [downloadOperation setQueuePriority:NSOperationQueuePriorityNormal];
            }
        }
        [decodeOperation setQueuePriority:NSOperationQueuePriorityNormal];
    }
    NSMutableSet *listeners = [[[self class] currentListeners] objectForKey:cacheKey];
    if (listeners != nil) {
        [listeners addObject:imageView];
    } else {
        listeners = [NSMutableSet setWithObject:imageView];
    }
    [[[self class] currentListeners] setObject:listeners forKey:cacheKey];
    [[[self class] imageViewLock] unlock];
}

+ (void)removeImageView:(ILKImageView*)imageView forCacheKey:(NSString *)cacheKey
{
    [[[self class] imageViewLock] lock];
    NSMutableSet *listeners = [[[self class] currentListeners] objectForKey:cacheKey];
    if (listeners != nil) {
        [listeners removeObject:imageView];
        if ([listeners count] == 0) {
            [[[self class] currentListeners] removeObjectForKey:cacheKey];
            ILKImageDecode *operation = [[[self class] currentOperations] objectForKey:cacheKey];
            if (operation != nil) {
                [operation cancel];
            }
            [[[self class] currentOperations] removeObjectForKey:cacheKey];
        } else {
            [[[self class] currentListeners] setObject:listeners forKey:cacheKey];
        }
    }
    [[[self class] imageViewLock] unlock];
}

+ (NSString *)cacheKeyForUrlString:(NSString *)urlString withAttributes:(NSDictionary *)attributes
{
  NSMutableArray *mutableArray = [NSMutableArray arrayWithObject:urlString];
  if (attributes.count > 0) {
      [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
          [mutableArray addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
      }];
  }
  return [mutableArray componentsJoinedByString:@"&"];
}

- (void)dealloc
{
    [cacheKey release];
    [_urlString release];
    [super dealloc];
}

- (void)setUrlString:(NSString *)urlString
{
  [self setUrlString:urlString withAttributes:nil];
}

- (void)setUrlString:(NSString *)urlString withAttributes:(NSDictionary *)attributes
{
    if (urlString == nil) {
        // Nop for a nil url, should set image property to nil to clear
        return;
    }
    if (_urlString) {
        // Attempt to remove the previous image operations
        [[self class] removeImageView:self forCacheKey:cacheKey];
        [_urlString autorelease];
        _urlString = nil;
    }
    _urlString = [urlString copy];
    if (_urlString != nil) {
        // Prepare attributes
        NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionary];
        if (attributes != nil) {
            [mutableAttributes addEntriesFromDictionary:attributes];
        }
        if (mutableAttributes[ILKImageSizeAttributeName] == nil) {
            mutableAttributes[ILKImageSizeAttributeName] = [NSValue valueWithCGSize:self.frame.size];
        }
        if (mutableAttributes[ILKViewContentModeAttributeName] == nil) {
            mutableAttributes[ILKViewContentModeAttributeName] = @(ILKViewContentModeScaleAspectFill);
        }
        // Check for valid image size
        CGSize imageSize = [mutableAttributes[ILKImageSizeAttributeName] CGSizeValue];
        NSAssert(imageSize.width > 0.0f, @"ERROR: ILKImageSizeAttribute width cannot be zero");
        NSAssert(imageSize.height > 0.0f, @"ERROR: ILKImageSizeAttribute height cannot be zero");
        // Cache lookup
        cacheKey = [[[self class] cacheKeyForUrlString:urlString withAttributes:[mutableAttributes.copy autorelease]] retain];
        UIImage *cachedImage = [[[self class] imageCache] objectForKey:cacheKey];
        if (cachedImage != nil) {
            // If refreshed, re-animate image loading
            if (_refresh) {
                _refresh = NO;
                [self didFinishProcessingImage:cachedImage forCacheKey:cacheKey];
            }
            // Else, load image instantly
            else {
                self.image = cachedImage;
            }
        } else {
            // Start image download
            [[self class] addImageView:self forUrlString:_urlString withAttributes:[mutableAttributes.copy autorelease]];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([object isKindOfClass:[ILKImageDecode class]]) {
        ILKImageDecode *operation = object;
        NSString *operationCacheKey = [[self class] cacheKeyForUrlString:operation.urlString withAttributes:operation.attributes];
        if ([cacheKey isEqualToString:operationCacheKey]) {
            [self didFinishProcessingImage:operation.processedImage forCacheKey:operationCacheKey];
        }
    }
}

- (void)didFinishProcessingImage:(UIImage *)processedImage forCacheKey:(NSString*)cacheKey
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.alpha = 0.0f;
        self.image = processedImage;
        [UIView animateWithDuration:0.5f animations:^{
            self.alpha = 1.0f;
        }];
    });
}

@end
