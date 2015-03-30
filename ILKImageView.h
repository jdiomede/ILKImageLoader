//
//  ILKImageView.h
//  ImageLoader
//
//  Created by James Diomede on 5/1/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import <UIKit/UIKit.h>

enum {
    ILKImageDownloadStateInitialized,
    ILKImageDownloadStateExecuting,
    ILKImageDownloadStateFinished
};
typedef NSUInteger ILKImageDownloadState;

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

@interface ILKImageDecode : NSOperation {
    BOOL cancelled;
    NSData *imageData;
    NSUInteger observerCount;
}

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, retain) UIImage *decodedImage;

- (id)initWithImageData:(NSData *)initImageData forUrlString:(NSString*)urlString;

@end

@interface ILKImageView : UIImageView

+ (NSCache*)imageCache;
+ (NSOperationQueue*)downloadOperationQueue;
+ (NSOperationQueue*)decodeOperationQueue;
+ (NSMutableDictionary*)currentOperations;
+ (NSMutableDictionary*)currentListeners;
+ (NSRecursiveLock*)imageViewLock;

+ (void)imageForUrlDidFinishLoading:(NSString*)urlString fromOperation:(ILKImageDecode*)operation;
+ (void)addImageView:(ILKImageView*)imageView forUrl:(NSString*)urlString;
+ (void)removeImageView:(ILKImageView*)imageView forUrl:(NSString*)urlString;

@property (nonatomic, copy) NSString *urlString;

- (id)initWithFrame:(CGRect)frame forUrlString:(NSString*)initURLString;

@end
