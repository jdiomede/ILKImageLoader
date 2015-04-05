//
//  ILKImageView.h
//  ImageLoader
//
//  Created by James Diomede on 5/1/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *const ILKImageSizeAttributeName;
extern NSString *const ILKViewContentModeAttributeName;
extern NSString *const ILKCornerRadiusAttributeName;
extern NSString *const ILKRectCornerAttributeName;

typedef NS_ENUM(NSInteger, ILKViewContentMode) {
  ILKViewContentModeScaleAspectFit,
  ILKViewContentModeScaleAspectFill
};

typedef NS_ENUM(NSUInteger, ILKRectCorner){
  ILKRectCornerBottomLeft  = 1 << 0,
  ILKRectCornerBottomRight = 1 << 1,
  ILKRectCornerTopLeft     = 1 << 2,
  ILKRectCornerTopRight    = 1 << 3,
  ILKRectCornerAllCorners  = ~0UL
};

@class ILKImageDecode;

@interface ILKImageView : UIImageView {
  NSString *cacheKey;
}

+ (NSCache*)imageCache;
+ (NSOperationQueue*)downloadOperationQueue;
+ (NSOperationQueue*)decodeOperationQueue;
+ (NSMutableDictionary*)currentOperations;
+ (NSMutableDictionary*)currentListeners;
+ (NSRecursiveLock*)imageViewLock;

+ (void)addImageView:(ILKImageView*)imageView forUrlString:(NSString*)urlString withAttributes:(NSDictionary*)attributes;
+ (void)removeImageView:(ILKImageView*)imageView forCacheKey:(NSString*)cacheKey;
+ (void)imageDidFinishLoadingForCacheKey:(NSString*)cacheKey fromOperation:(ILKImageDecode*)operation;

+ (NSString *)cacheKeyForUrlString:(NSString *)urlString withAttributes:(NSDictionary *)attributes;

@property (nonatomic, assign) BOOL refresh;
@property (nonatomic, copy) NSString *urlString;

- (void)setUrlString:(NSString*)urlString withAttributes:(NSDictionary*)attributes;
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
- (void)didFinishProcessingImage:(UIImage *)decodedImage forCacheKey:(NSString*)cacheKey;

@end
