//
//  AppDelegate.h
//  ILKImageLoader
//
//  Created by James Diomede on 5/4/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ILKImageView.h"
#import "ExampleTableViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) ExampleTableViewController *exampleTableViewController;
@property (strong, nonatomic) ILKImageView *imageView;
@property (strong, nonatomic) UIViewController *viewController;

@end
