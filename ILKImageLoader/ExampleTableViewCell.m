//
//  ExampleTableViewCell.m
//  ILKImageLoader
//
//  Created by James Diomede on 3/29/15.
//  Copyright (c) 2015 James Diomede. All rights reserved.
//

#import "ExampleTableViewCell.h"

@interface ExampleTableViewCell()

@end

@implementation ExampleTableViewCell

- (void)dealloc {
    [_ilkImageView release];
    [_mainLabel release];
    [super dealloc];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
      // TODO: remove clips to bounds, truncate image
      _ilkImageView = [[[ILKImageView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width)] autorelease];
      _ilkImageView.contentMode = UIViewContentModeScaleAspectFill;
      _ilkImageView.clipsToBounds = YES;
      [self.contentView addSubview:_ilkImageView];
      _mainLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 30)] autorelease];
      _mainLabel.backgroundColor = [UIColor clearColor];
      _mainLabel.textColor = [UIColor grayColor];
      _mainLabel.adjustsFontSizeToFitWidth = YES;
      _mainLabel.textAlignment = NSTextAlignmentCenter;
      [self.contentView addSubview:_mainLabel];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
