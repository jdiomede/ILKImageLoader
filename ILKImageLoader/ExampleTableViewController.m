//
//  ExampleTableViewController.m
//  ILKImageLoader
//
//  Created by James Diomede on 5/5/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import "ExampleTableViewController.h"

@implementation ILKImageUrlDownload

- (void)dealloc
{
    [_arrayOfUrls release];
    [responseData release];
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self) {
        responseData = [[NSMutableData alloc] init];
        _arrayOfUrls = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)start
{
    NSString *httpHostAndPath = @"http://api.flickr.com/services/rest";
    NSString *httpUrlParamters = [NSString stringWithFormat:@"%@%@%@%@",
                                  @"?api_key=496a5ec35ff7653a836f70b1d9c7eac0",
                                  @"&method=flickr.photos.getRecent",
                                  @"&format=json",
                                  @"&nojsoncallback=1"];
    NSLog(@"Launch image url refresh from thread: %@", [NSThread currentThread]);
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", httpHostAndPath, httpUrlParamters]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    NSURLConnection *connection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO] autorelease];
    if (connection == NULL) {
        self.error = [NSError errorWithDomain:NSOSStatusErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
        [self end];
    } else {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [connection scheduleInRunLoop:runLoop forMode:NSRunLoopCommonModes];
        [connection start];
        [runLoop run];
    }
}

- (void)end
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    state = ILKImageUrlDownloadStateFinished;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isConcurrent    { return YES; }
- (BOOL)isExecuting     { return (state == ILKImageUrlDownloadStateExecuting); }
- (BOOL)isFinished      { return (state == ILKImageUrlDownloadStateFinished); }

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.status = ((NSHTTPURLResponse*)response).statusCode;
    [responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error = error;
    [self end];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSLog(@"Append image url data from thread: %@", [NSThread currentThread]);
    if (responseData == NULL) {
        responseData = [[NSMutableData alloc] init];
    }
    [responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSError *error = NULL;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
    NSDictionary *photos = [responseDict valueForKey:@"photos"];
    NSArray *photoArray = [photos valueForKey:@"photo"];
    for (NSDictionary *photo in photoArray) {
        //http://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}.jpg
        NSString *photoUrl = [NSString stringWithFormat:@"http://farm%@.staticflickr.com/%@/%@_%@.jpg",
                              [photo valueForKey:@"farm"],
                              [photo valueForKey:@"server"],
                              [photo valueForKey:@"id"],
                              [photo valueForKey:@"secret"]];
        [self.arrayOfUrls addObject:photoUrl];
    }
    [self end];
}

@end

@interface ExampleTableViewController ()

@end

@implementation ExampleTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        imageUrls = nil;
        operationQueue = [[NSOperationQueue alloc] init];
        [self refreshImageUrls];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 320.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return imageUrls.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == NULL) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        [cell.contentView addSubview:[[ILKImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 320) forUrlString:[imageUrls objectAtIndex:indexPath.row]]];
    }
    
    for (id subview in cell.contentView.subviews) {
        if ([subview isKindOfClass:[ILKImageView class]]) {
            ILKImageView *imageView = subview;
            if (![imageView.urlString isEqualToString:[imageUrls objectAtIndex:indexPath.row]]) {
                imageView.image = nil;
                imageView.urlString = [imageUrls objectAtIndex:indexPath.row];
            }
        }
    }
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)refreshImageUrls
{
    ILKImageUrlDownload *operation = [[[ILKImageUrlDownload alloc] init] autorelease];
    [operation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
    [operationQueue addOperation:operation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([object isKindOfClass:[ILKImageUrlDownload class]]) {
        ILKImageUrlDownload *operation = object;
        [operation removeObserver:self forKeyPath:@"isFinished"];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Reload table view from main thread: %@, with %d photos", [NSThread currentThread], operation.arrayOfUrls.count);
            imageUrls = [operation.arrayOfUrls copy];
            [self.tableView reloadData];
        });
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //nop
}

@end
