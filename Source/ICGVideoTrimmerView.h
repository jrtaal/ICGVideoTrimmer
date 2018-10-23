//
//  ICGVideoTrimmerView.h
//  ICGVideoTrimmer
//
//  Created by Huong Do on 1/18/15.
//  Copyright (c) 2015 ichigo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol ICGVideoTrimmerDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface ICGVideoTrimmerView : UIView

// Video to be trimmed
@property (strong, nonatomic, nullable) AVAsset *asset;

// Theme color for the trimmer view
@property (strong, nonatomic) UIColor *themeColor;

// Maximum length for the trimmed video
@property (assign, nonatomic) CGFloat maxDuration;

// Minimum length for the trimmed video
@property (assign, nonatomic) CGFloat minDuration;

// Current start time
@property (nonatomic) CGFloat startTime;

// Current end time
@property (nonatomic) CGFloat endTime;

// Show ruler view on the trimmer view or not
@property (assign, nonatomic) BOOL showsRulerView;

// Number of seconds between
@property (assign, nonatomic) NSInteger rulerLabelInterval;

// Customize color for tracker
@property (strong, nonatomic) UIColor *trackerColor;

// Custom image for the left thumb
@property (strong, nonatomic, nullable) UIImage *leftThumbImage;

// Custom image for the right thumb
@property (strong, nonatomic, nullable) UIImage *rightThumbImage;

// Custom width for the top and bottom borders
@property (assign, nonatomic) CGFloat borderWidth;

// Custom width for thumb
@property (assign, nonatomic) CGFloat thumbWidth;

@property (weak, nonatomic, nullable) id<ICGVideoTrimmerDelegate> delegate;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame asset:(AVAsset *)asset delegate:(id<ICGVideoTrimmerDelegate>) delegate NS_DESIGNATED_INITIALIZER;

- (void)resetSubviews;

- (void)seekToTime:(CGFloat)startTime animated:(BOOL)animated;

- (void)hideTracker:(BOOL)flag;

-(void)setVideoBoundsToStartTime:(CGFloat)startTime endTime:(CGFloat)endTime offset:(CGFloat)offset;


@end

NS_ASSUME_NONNULL_END

@protocol ICGVideoTrimmerDelegate <NSObject>

@optional
- (void)trimmerView:(nonnull ICGVideoTrimmerView *)trimmerView
didChangeLeftPosition:(CGFloat)startTime
      rightPosition:(CGFloat)endTime
             offset:(CGFloat)offset
          movedLeft:(BOOL)movedLEft;

- (void)trimmerViewDidEndEditing:(nonnull ICGVideoTrimmerView *)trimmerView;

- (void)trimmerView:(nonnull ICGVideoTrimmerView *)trimmerView didMoveTrackerToTime:(CGFloat)time;

@end


