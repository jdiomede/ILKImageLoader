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

- (void)dealloc
{
    [_ilkImageView release];
    [_mainLabel release];
    [super dealloc];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _ilkImageView = [[[ILKImageView alloc] init] autorelease];
        _ilkImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_ilkImageView];
        _mainLabel = [[[UILabel alloc] init] autorelease];
        _mainLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _mainLabel.backgroundColor = [UIColor clearColor];
        _mainLabel.textColor = [UIColor grayColor];
        _mainLabel.adjustsFontSizeToFitWidth = YES;
        _mainLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_mainLabel];
        NSDictionary *views = @{@"ilkImageView":_ilkImageView, @"mainLabel":_mainLabel};
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[ilkImageView]|" options:0 metrics:nil views:views]];
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[ilkImageView]|" options:0 metrics:nil views:views]];
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[mainLabel]|" options:0 metrics:nil views:views]];
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[mainLabel(==height)]" options:0 metrics:@{@"height":@(30.0f)} views:views]];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
}

@end
