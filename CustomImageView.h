//
//  CustomImageView.h
//  ImageLoader
//
//  Created by James Diomede on 5/1/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import <UIKit/UIKit.h>

enum {
    CustomImageDownloadStateInitialized,
    CustomImageDownloadStateExecuting,
    CustomImageDownloadStateFinished
};
typedef NSUInteger CustomImageDownloadState;

@interface CustomImageDecode : NSOperation {
    NSData *imageData;
}

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, retain) UIImage *decodedImage;

- (id)initWithImageData:(NSData *)initImageData forURLString:(NSString*)initURLString;

@end

@interface CustomImageDownload : NSOperation <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
    CustomImageDownloadState state;
}

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, retain) NSError *error;
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, retain) NSMutableData *response;

- (id)initWithURLString:(NSString*)initURLString;

@end

@interface CustomImageView : UIImageView

+ (NSCache*)imageCache;
+ (NSOperationQueue*)operationQueue;

- (id)initWithFrame:(CGRect)frame forURLString:(NSString*)initURLString;

@end
