//
//  AppDelegate.m
//  ILKImageLoader
//
//  Created by James Diomede on 5/4/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import "AppDelegate.h"
#import "ILKImageView.h"

@implementation AppDelegate

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (void) updateUrlString
{
    self.imageView.urlString = @"http://coolalbumreview.com/wp-content/uploads/2012/01/prince_controversy_fc.jpg";
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    self.exampleTableViewController = [[[ExampleTableViewController alloc] initWithStyle:UITableViewStylePlain] autorelease];
    [self.exampleTableViewController.tableView setFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    /*self.viewController = [[[UIViewController alloc] init] autorelease];
    self.viewController.view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)] autorelease];
    [self.viewController.view setBackgroundColor:[UIColor whiteColor]];
    self.imageView = [[[ILKImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) forUrlString:@"http://4.bp.blogspot.com/-jxRHIs4mRXs/UD9cXrKBYqI/AAAAAAAAC-Y/wEYwHAV5qIg/s1600/Prince-For-You.jpeg"] autorelease];
    [self performSelector:@selector(updateUrlString) withObject:self afterDelay:0.01f];
    [self.viewController.view addSubview:self.imageView];*/
    self.window.rootViewController = self.exampleTableViewController;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
