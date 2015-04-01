//
//  ExampleTableViewCell.h
//  ILKImageLoader
//
//  Created by James Diomede on 3/29/15.
//  Copyright (c) 2015 James Diomede. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ILKImageView.h"

@interface ExampleTableViewCell : UITableViewCell

@property (nonatomic, retain) UILabel *mainLabel;
@property (nonatomic, retain) ILKImageView *ilkImageView;

@end
