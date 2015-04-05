//
//  ExampleTableViewController.m
//  ILKImageLoader
//
//  Created by James Diomede on 5/5/13.
//  Copyright (c) 2013 James Diomede. All rights reserved.
//

#import "ExampleTableViewController.h"

#import "ExampleTableViewCell.h"

#pragma mark - ILKImageUrlDownload

@implementation ILKImageUrlDownload

- (void)dealloc
{
    [_error release];
    [_arrayOfUrls release];
    [responseData release];
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self) {
        responseData = [[NSMutableData alloc] init];
        _error = NULL;
        _arrayOfUrls = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)start
{
    NSString *httpHostAndPath = @"https://api.flickr.com/services/rest";
    NSString *httpUrlParamters = [NSString stringWithFormat:@"%@%@%@%@",
                                  @"?api_key=496a5ec35ff7653a836f70b1d9c7eac0",
                                  @"&method=flickr.photos.getRecent",
                                  @"&format=json",
                                  @"&nojsoncallback=1"];
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
    NSLog(@"Connection failed with error: %@", error.description);
    [self end];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
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
    NSMutableArray *mutableArray = [[[NSMutableArray alloc] init] autorelease];
    for (NSDictionary *photo in photoArray) {
        //http://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}.jpg
        NSString *photoUrl = [NSString stringWithFormat:@"http://farm%@.staticflickr.com/%@/%@_%@_b.jpg",
                              [photo valueForKey:@"farm"],
                              [photo valueForKey:@"server"],
                              [photo valueForKey:@"id"],
                              [photo valueForKey:@"secret"]];
        [mutableArray addObject:photoUrl];
    }
    self.arrayOfUrls = [mutableArray.copy autorelease];
    [self end];
}

@end

#pragma mark - ExampleTableViewController

static NSString * const reuseIdentifier = @"ExampleTableViewCell";

@implementation ExampleTableViewController

- (void)dealloc
{
    [imageUrls release];
    [operationQueue release];
    [super dealloc];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        imageUrls = nil;
        operationQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView registerClass:[ExampleTableViewCell class] forCellReuseIdentifier:reuseIdentifier];
    self.title = @"Recent Photos on Flickr";
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.tableFooterView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
    self.refreshControl = [[[UIRefreshControl alloc] init] autorelease];
    [self.refreshControl addTarget:self action:@selector(refreshImageUrls) forControlEvents:UIControlEventValueChanged];
    [self refreshImageUrls];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // TODO: proactively clear cache
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [UIScreen mainScreen].bounds.size.width;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return imageUrls.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ExampleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
  
    if (![cell.ilkImageView.urlString isEqualToString:[imageUrls objectAtIndex:indexPath.row]]) {
        cell.ilkImageView.image = nil;
        [cell.ilkImageView setUrlString:imageUrls[indexPath.row] withAttributes:@{ILKImageSizeAttributeName:[NSValue valueWithCGSize:CGSizeMake([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width)], ILKViewContentModeAttributeName:@(ILKViewContentModeScaleAspectFill)}];
        cell.mainLabel.text = @"Tap to reload data source";
    }
    
    return cell;
}

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
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            [self.refreshControl endRefreshing];
            imageUrls = operation.arrayOfUrls.copy;
            [self.tableView reloadData];
        });
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    for (ExampleTableViewCell *cell in self.tableView.visibleCells) {
        cell.ilkImageView.refresh = YES;
    }
    [self refreshImageUrls];
}

@end
