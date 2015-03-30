//
//  ExampleTableViewController.h
//  ILKImageLoader
//
//  Created by James Diomede on 5/5/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ILKImageView.h"

enum {
    ILKImageUrlDownloadStateInitialized,
    ILKImageUrlDownloadStateExecuting,
    ILKImageUrlDownloadStateFinished
};
typedef NSUInteger ILKImageUrlDownloadState;

@interface ILKImageUrlDownload : NSOperation <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
    ILKImageUrlDownloadState state;
    NSMutableData *responseData;
}

@property (nonatomic, retain) NSError *error;
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, retain) NSArray *arrayOfUrls;

@end

@interface ExampleTableViewController : UITableViewController {
    NSArray *imageUrls;
    NSOperationQueue *operationQueue;
}

@end
