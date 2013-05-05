//
//  ILKImageView.h
//  ImageLoader
//
//  Created by James Diomede on 5/1/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ILKImageDecode : NSOperation {
    NSData *imageData;
}

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, retain) UIImage *decodedImage;

- (id)initWithImageData:(NSData *)initImageData forUrlString:(NSString*)urlString;

@end

enum {
    ILKImageDownloadStateInitialized,
    ILKImageDownloadStateExecuting,
    ILKImageDownloadStateFinished
};
typedef NSUInteger ILKImageDownloadState;

@interface ILKImageDownload : NSOperation <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
    ILKImageDownloadState state;
}

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, retain) NSError *error;
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, retain) NSMutableData *response;

- (id)initWithUrlString:(NSString*)urlString;

@end

@interface ILKImageView : UIImageView

+ (NSCache*)imageCache;
+ (NSOperationQueue*)downloadOperationQueue;
+ (NSOperationQueue*)decodeOperationQueue;
+ (NSMutableDictionary*)currentOperations;
+ (NSLock*)lockCurrentOperations;

@property (nonatomic, copy) NSString *urlString;

- (id)initWithFrame:(CGRect)frame forUrlString:(NSString*)initURLString;

@end
