 //
//  ICGVideoTrimmerView.m
//  ICGVideoTrimmer
//
//  Created by Huong Do on 1/18/15.
//  Copyright (c) 2015 ichigo. All rights reserved.
//

#import "ICGVideoTrimmerView.h"
#import "ICGThumbView.h"
#import "ICGRulerView.h"



@interface HitTestView : UIView
@property (assign, nonatomic) UIEdgeInsets hitTestEdgeInsets;
- (BOOL)pointInside:(CGPoint)point;

@end

@implementation HitTestView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    return [self pointInside:point];
}

- (BOOL)pointInside:(CGPoint)point
{
    CGRect relativeFrame = self.bounds;
    CGRect hitFrame = UIEdgeInsetsInsetRect(relativeFrame, _hitTestEdgeInsets);
    return CGRectContainsPoint(hitFrame, point);
}

@end


@interface ICGVideoTrimmerView() <UIScrollViewDelegate>

@property (strong, nonatomic) UIView *contentView;
@property (strong, nonatomic) UIView *framesView;
@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) AVAssetImageGenerator *imageGenerator;

@property (strong, nonatomic) HitTestView *leftOverlayView;
@property (strong, nonatomic) HitTestView *rightOverlayView;
@property (strong, nonatomic) ICGThumbView *leftThumbView;
@property (strong, nonatomic) ICGThumbView *rightThumbView;
@property (strong, nonatomic) ICGRulerView *rulerView;


@property (assign, nonatomic) BOOL isDraggingRightOverlayView;
@property (assign, nonatomic) BOOL isDraggingLeftOverlayView;

@property (strong, nonatomic) UIView *topBorder;
@property (strong, nonatomic) UIView *bottomBorder;

@property (nonatomic) CGFloat widthPerSecond;

@property (nonatomic) CGPoint leftStartPoint;
@property (nonatomic) CGPoint rightStartPoint;
@property (nonatomic) CGFloat overlayWidth;

@property (nonatomic) NSTimeInterval prevTrackerTime;



@end

@implementation ICGVideoTrimmerView {
    NSTimeInterval _startTime;
    NSTimeInterval _endTime;
    AVAsset * _asset;
    BOOL _panningTracker;
}

@synthesize trackerView = _trackerView;

#pragma mark - Initiation

- (instancetype)initWithFrame:(CGRect)frame
{
    NSAssert(NO, nil);
    @throw nil;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (!(self = [super initWithCoder:aDecoder])) return nil;

    [self setDefaults];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame asset:(AVAsset *)asset delegate:(id<ICGVideoTrimmerDelegate>) delegate
{
    self = [super initWithFrame:frame];
    if (self) {
        _delegate = delegate;
        _asset = asset;
        [self setDefaults];
        [self loadViews];
        [self resetSubviews];
    }
    return self;
}

-(void)setDefaults {
    _maxDuration = 15.0;
    _minDuration = 3.0;
    _trackerColor = [UIColor whiteColor];
    _borderWidth =  2.0;
    _thumbWidth = 15.0;
    _rulerLabelInterval = 5.0;
    _themeColor = [UIColor lightGrayColor];
}

-(void)awakeFromNib {
    [super awakeFromNib];
    [self loadViews];
}

#define EDGE_EXTENSION_FOR_THUMB 30

-(void)loadViews {
    CGFloat radius = 5.0;

    self.layer.masksToBounds = true;
    self.layer.cornerRadius = radius;

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame))];
    [self addSubview:self.scrollView];
    [self.scrollView setDelegate:self];
    [self.scrollView setShowsHorizontalScrollIndicator:NO];

    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.scrollView.frame), CGRectGetHeight(self.scrollView.frame))];
    [self.scrollView setContentSize:self.contentView.frame.size];
    [self.scrollView addSubview:self.contentView];
    
    // add borders
    self.topBorder = [[UIView alloc] init];
    [self.topBorder setBackgroundColor:self.themeColor];
    [self addSubview:self.topBorder];
    
    self.bottomBorder = [[UIView alloc] init];
    [self.bottomBorder setBackgroundColor:self.themeColor];
    [self addSubview:self.bottomBorder];

    
    // add left overlay view
    self.leftOverlayView = [[HitTestView alloc] initWithFrame:CGRectMake(0, 0, 100, CGRectGetHeight(self.frame))];
    self.leftOverlayView.hitTestEdgeInsets = UIEdgeInsetsMake(0, 0, 0, -(EDGE_EXTENSION_FOR_THUMB));
    CGRect leftThumbFrame = CGRectMake(100 - self.thumbWidth, 0, self.thumbWidth, CGRectGetHeight(self.frame));
    if (self.leftThumbImage) {
        self.leftThumbView = [[ICGThumbView alloc] initWithFrame:leftThumbFrame thumbImage:self.leftThumbImage];
    } else {
        self.leftThumbView = [[ICGThumbView alloc] initWithFrame:leftThumbFrame color:self.themeColor right:NO];
    }
    self.leftThumbView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
    self.leftThumbView.radius = radius;
    
    self.clipsToBounds = false;
    
    [self.leftThumbView.layer setMasksToBounds:YES];
    [self.leftOverlayView addSubview:self.leftThumbView];
    [self.leftOverlayView setUserInteractionEnabled:YES];
    [self.leftOverlayView setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:0.6]];
    [self addSubview:self.leftOverlayView];

    CGFloat rightViewFrameX = CGRectGetWidth(self.framesView.frame) < CGRectGetWidth(self.frame) ? CGRectGetMaxX(self.framesView.frame) : CGRectGetWidth(self.frame) - self.thumbWidth;
    self.rightOverlayView = [[HitTestView alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.frame) < rightViewFrameX ? CGRectGetWidth(self.framesView.frame) : rightViewFrameX , 0, self.overlayWidth, CGRectGetHeight(self.frame))];
    self.rightOverlayView.hitTestEdgeInsets = UIEdgeInsetsMake(0, -(EDGE_EXTENSION_FOR_THUMB), 0, 0);
    CGRect rightThumbFrame = CGRectMake(0, 0, self.thumbWidth, CGRectGetHeight(self.frame));
    if (self.rightThumbImage) {
        self.rightThumbView = [[ICGThumbView alloc] initWithFrame:rightThumbFrame thumbImage:self.rightThumbImage];
    } else {
        self.rightThumbView = [[ICGThumbView alloc] initWithFrame:rightThumbFrame color:self.themeColor right:YES];
    }
    self.rightThumbView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
    self.rightThumbView.radius = radius;
    
    [self.rightThumbView.layer setMasksToBounds:YES];
    [self.rightOverlayView addSubview:self.rightThumbView];
    [self.rightOverlayView setUserInteractionEnabled:YES];
    [self.rightOverlayView setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:0.6]];
    [self addSubview:self.rightOverlayView];
    
    self->_trackerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, self.frame.size.height)];
    self.trackerView.backgroundColor = [UIColor whiteColor];
    self.trackerView.layer.masksToBounds = true;
    [self addSubview:self.trackerView];
    UIPanGestureRecognizer * trackerGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panTracker:)];
    [self.trackerView addGestureRecognizer:trackerGestureRecognizer];
    self.trackerView.userInteractionEnabled = true;
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveOverlayView:)];
    [self addGestureRecognizer:panGestureRecognizer];
}

- (void)setThemeColor:(UIColor *)themeColor {
    _themeColor = themeColor;
    
    [self.bottomBorder setBackgroundColor:_themeColor];
    [self.topBorder setBackgroundColor:_themeColor];
    self.leftThumbView.color = _themeColor;
    self.rightThumbView.color = _themeColor;
}

-(AVAsset *)asset {
    return _asset;
}
-(void)setAsset:(AVAsset *)asset {
    _asset = asset;
    //[self resetSubviews];
}

-(void)layoutSubviews {
    [super layoutSubviews];

    if (self.frame.size.width != self.scrollView.frame.size.width)
        [self resetSubviews];
}
#pragma mark - Private methods


-(void) didMoveToWindow {
    [super didMoveToWindow]; // (does nothing by default)
    if (self.window == nil) {
        if(self.imageGenerator != nil){
            [self.imageGenerator cancelAllCGImageGeneration];
        }
    }
}


- (void)resetSubviews
{

    CALayer *sideMaskingLayer = [CALayer new];
    sideMaskingLayer.backgroundColor = [UIColor blackColor].CGColor;
    sideMaskingLayer.frame = CGRectMake(0, -10, self.frame.size.width, self.frame.size.height + 20);
    self.layer.mask = sideMaskingLayer;
    
    [self setBackgroundColor:[UIColor clearColor]];
        
    self.scrollView.frame = CGRectMake(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
    self.contentView.frame = CGRectMake(0, 0, CGRectGetWidth(self.scrollView.frame), CGRectGetHeight(self.scrollView.frame));
    
    [self.framesView removeFromSuperview];
    double ratio = self.showsRulerView ? 0.7 : 1.0;
    //self.scrollView.contentInset = UIEdgeInsetsMake(0, self.thumbWidth, 0, self.thumbWidth);
    self.framesView = [[UIView alloc] initWithFrame:CGRectMake(self.thumbWidth, 0, CGRectGetWidth(self.contentView.frame)-(2*self.thumbWidth), CGRectGetHeight(self.contentView.frame)*ratio)];
    [self.framesView.layer setMasksToBounds:YES];
    [self.contentView addSubview:self.framesView];
    
    [self addFrames];
    
    if (self.showsRulerView) {
        [self.rulerView removeFromSuperview];
        CGRect rulerFrame = CGRectMake(0, CGRectGetHeight(self.contentView.frame)*0.7, CGRectGetWidth(self.contentView.frame)+self.thumbWidth, CGRectGetHeight(self.contentView.frame)*0.3);
        self.rulerView = [[ICGRulerView alloc] initWithFrame:rulerFrame widthPerSecond:self.widthPerSecond themeColor:self.themeColor labelInterval:self.rulerLabelInterval];
        [self.contentView addSubview:self.rulerView];
    }
    
    // width for left and right overlay views
    self.overlayWidth =  CGRectGetWidth(self.frame) - (self.minDuration * self.widthPerSecond);
    
    // add left overlay view
    self.leftOverlayView.frame = CGRectMake(self.thumbWidth - self.overlayWidth, 0, self.overlayWidth, CGRectGetHeight(self.framesView.frame));
    
    // add right overlay view
    CGFloat rightViewFrameX = CGRectGetWidth(self.framesView.frame) < CGRectGetWidth(self.frame) ? CGRectGetMaxX(self.framesView.frame) : CGRectGetWidth(self.frame) - self.thumbWidth;
    self.rightOverlayView.frame = CGRectMake(CGRectGetWidth(self.frame) < rightViewFrameX ? CGRectGetWidth(self.framesView.frame) : rightViewFrameX , 0, self.overlayWidth, CGRectGetHeight(self.framesView.frame));
    
    self.trackerView.frame = CGRectMake(0, -5, self.thumbWidth, CGRectGetHeight(self.framesView.frame) + 10);
    
    
    [self updateBorderFrames];
    [self notifyDelegateOfDidChange];
}

- (void)updateBorderFrames
{
    CGFloat height = self.borderWidth;
    [self.topBorder setFrame:CGRectMake(CGRectGetMaxX(self.leftOverlayView.frame), 0, CGRectGetMinX(self.rightOverlayView.frame)-CGRectGetMaxX(self.leftOverlayView.frame), height)];
    [self.bottomBorder setFrame:CGRectMake(CGRectGetMaxX(self.leftOverlayView.frame), CGRectGetHeight(self.framesView.frame)-height, CGRectGetMinX(self.rightOverlayView.frame)-CGRectGetMaxX(self.leftOverlayView.frame), height)];
}

- (void)panTracker:(UIPanGestureRecognizer*)gesture {
    if (! self.trackerView)
        return;
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            _panningTracker = true;
            break;
            
        case UIGestureRecognizerStateChanged: {
            CGPoint dist = [gesture locationInView:self];
            NSTimeInterval time = (dist.x - self.thumbWidth + self.scrollView.contentOffset.x) / self.widthPerSecond;
            time = MAX(0.0, MIN(CMTimeGetSeconds(self.asset.duration), time));
            if isinf(time)
                break;
            CGFloat offset = time * self.widthPerSecond + self.thumbWidth - self.scrollView.contentOffset.x;
            self.trackerView.center = CGPointMake(offset, self.trackerView.center.y);
            [self.delegate trimmerView:self didMoveTrackerToTime:time];
            break;
        }
        case UIGestureRecognizerStateEnded: {
            _panningTracker = false;
        }
            
        default:
            break;
    }
}



- (void)moveOverlayView:(UIPanGestureRecognizer *)gesture
{
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        {
            BOOL isRight =  [_rightOverlayView pointInside:[gesture locationInView:_rightOverlayView]];
            BOOL isLeft  =  [_leftOverlayView pointInside:[gesture locationInView:_leftOverlayView]];
            
            if (isRight){
                self.rightStartPoint = [gesture locationInView:self];
                _isDraggingRightOverlayView = YES;
                _isDraggingLeftOverlayView = NO;
            }
            else if (isLeft){
                self.leftStartPoint = [gesture locationInView:self];
                _isDraggingRightOverlayView = NO;
                _isDraggingLeftOverlayView = YES;
            } else {
                _isDraggingLeftOverlayView = _isDraggingRightOverlayView = NO;
                self.rightStartPoint = [gesture locationInView:self];
                self.leftStartPoint = [gesture locationInView:self];
            }
    
        }    break;
        case UIGestureRecognizerStateChanged:
        {
          CGPoint point = [gesture locationInView:self];

              // Right
          if (_isDraggingRightOverlayView){

              CGFloat deltaX = point.x - self.rightStartPoint.x;

              CGPoint center = self.rightOverlayView.center;
              center.x += deltaX;
              CGFloat newRightViewMidX = center.x;
              CGFloat minX = CGRectGetMaxX(self.leftOverlayView.frame) + self.minDuration * self.widthPerSecond;
              CGFloat maxX = CMTimeGetSeconds([self.asset duration]) <= self.maxDuration + 0.5 ? CGRectGetMaxX(self.framesView.frame) : CGRectGetWidth(self.frame) - self.thumbWidth;
              if (newRightViewMidX - self.overlayWidth/2 < minX) {
                  newRightViewMidX = minX + self.overlayWidth/2;
              } else if (newRightViewMidX - self.overlayWidth/2 > maxX) {
                  newRightViewMidX = maxX + self.overlayWidth/2;
              }

              self.rightOverlayView.center = CGPointMake(newRightViewMidX, self.rightOverlayView.center.y);
              self.rightStartPoint = point;
          } else if (_isDraggingLeftOverlayView){

                  // Left
              CGFloat deltaX = point.x - self.leftStartPoint.x;

              CGPoint center = self.leftOverlayView.center;
              center.x += deltaX;
              CGFloat newLeftViewMidX = center.x;
              CGFloat maxWidth = CGRectGetMinX(self.rightOverlayView.frame) - (self.minDuration * self.widthPerSecond);
              CGFloat newLeftViewMinX = newLeftViewMidX - self.overlayWidth/2;
              if (newLeftViewMinX < self.thumbWidth - self.overlayWidth) {
                  newLeftViewMidX = self.thumbWidth - self.overlayWidth + self.overlayWidth/2;
              } else if (newLeftViewMinX + self.overlayWidth > maxWidth) {
                  newLeftViewMidX = maxWidth - self.overlayWidth / 2;
              }

              self.leftOverlayView.center = CGPointMake(newLeftViewMidX, self.leftOverlayView.center.y);
              self.leftStartPoint = point;
          }

          if (_isDraggingLeftOverlayView || _isDraggingRightOverlayView) {
              [self updateBorderFrames];
              [self notifyDelegateOfDidChange];
          }
          break;
        }
        case UIGestureRecognizerStateEnded:
        {
            [self notifyDelegateOfEndEditing];
        }
            
        default:
            break;
    }
}

- (void)seekToTime:(NSTimeInterval) time animated:(BOOL)animated
{
    if (!_panningTracker) {
        NSTimeInterval duration = fabs(_prevTrackerTime - time);
        _prevTrackerTime = time;
        
        CGFloat posToMove = time * self.widthPerSecond + self.thumbWidth - self.scrollView.contentOffset.x;
        CGFloat y = self.trackerView.center.y;
        if (animated){
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear|UIViewAnimationOptionBeginFromCurrentState animations:^{
                self.trackerView.center = CGPointMake(posToMove, y);
            } completion:nil ];
        }
        else{
            self.trackerView.center = CGPointMake(posToMove, y);
        }
    }
}


- (void)hideTracker:(BOOL)flag
{
    if ( flag == YES ) {
        self.trackerView.hidden = YES;
    } else {
        self.trackerView.alpha = 0.0;
        self.trackerView.hidden = NO;
        [UIView animateWithDuration:.3 animations:^{
            self.trackerView.alpha = 1;
        }];
    }
}

-(NSTimeInterval)startTime {
    return _startTime;
}

-(void)setStartTime:(NSTimeInterval)startTime {
    _startTime = startTime;

    CGFloat x = startTime * self.widthPerSecond;
    self.scrollView.contentOffset = CGPointMake(x, 0.0);
    float newLeftOverlayViewMidX = [self getMiddleXPointForLeftOverlayViewWithTime:startTime];
    self.leftOverlayView.center = CGPointMake(newLeftOverlayViewMidX, self.leftOverlayView.center.y);

    [self notifyDelegateOfDidChange];
}

-(NSTimeInterval)endTime {
    return _endTime;
}

-(void)setEndTime:(NSTimeInterval)endTime {
    _endTime = endTime;
    float newRightOverlayVideMidX = [self getMiddleXPointForRightOverlayViewWithTime:endTime];
    self.rightOverlayView.center = CGPointMake(newRightOverlayVideMidX, self.rightOverlayView.center.y);
    [self notifyDelegateOfDidChange];
}

-(void)setVideoBoundsToStartTime:(NSTimeInterval)startTime
                         endTime:(NSTimeInterval)endTime
                          offset:(NSTimeInterval)offset
{     //Validating the inputs.

    if (startTime < 0 || endTime < 0 || startTime >= endTime ||
        endTime > CMTimeGetSeconds([self.asset duration]) ||
        (endTime - startTime) < self.minDuration ||
        (endTime - startTime) > self.maxDuration)
        return;
    _startTime = startTime;
    _endTime = endTime;

    self.scrollView.contentOffset = CGPointMake(offset, 0.0);
    float newLeftOverlayViewMidX = [self getMiddleXPointForLeftOverlayViewWithTime:startTime];
    self.leftOverlayView.center = CGPointMake(newLeftOverlayViewMidX, self.leftOverlayView.center.y);
    
    float newRightOverlayVideMidX = [self getMiddleXPointForRightOverlayViewWithTime:endTime];
    self.rightOverlayView.center = CGPointMake(newRightOverlayVideMidX, self.rightOverlayView.center.y);
    
    [self notifyDelegateOfDidChange];
}


-(CGFloat)getMiddleXPointForLeftOverlayViewWithTime:(NSTimeInterval)time {

    CGFloat leftOverlayViewNewX = [self timeToOffset:time];
    
    CGFloat leftOverlayViewOldX = CGRectGetMaxX(self.leftOverlayView.frame);
    
    int leftDeltaX =  leftOverlayViewNewX-leftOverlayViewOldX;
    
    CGPoint leftCenter = _leftOverlayView.center;
    
    CGFloat newLeftViewMidX = leftCenter.x += leftDeltaX;;
    CGFloat maxWidth = CGRectGetMinX(_rightOverlayView.frame) - (_minDuration * _widthPerSecond);
    CGFloat newLeftViewMinX = newLeftViewMidX - _overlayWidth/2;
    if (newLeftViewMinX < _thumbWidth - _overlayWidth) {
        newLeftViewMidX = _thumbWidth - _overlayWidth + _overlayWidth/2;
    } else if (newLeftViewMinX + _overlayWidth > maxWidth) {
        newLeftViewMidX = maxWidth - _overlayWidth / 2;
    }

    return newLeftViewMidX;
    
}
-(CGFloat)getMiddleXPointForRightOverlayViewWithTime:(NSTimeInterval)time
{
    CGFloat rightOverlayViewNewX = [self timeToOffset:time];
    
    CGFloat rightOverlayViewOldX = CGRectGetMinX(self.rightOverlayView.frame);
    
    int rightDeltaX = rightOverlayViewNewX - rightOverlayViewOldX;
    
    CGPoint rightCenter = self.rightOverlayView.center;
    
    CGFloat newRightViewMidX = rightCenter.x += rightDeltaX;
    CGFloat minX = CGRectGetMaxX(self.leftOverlayView.frame) + self.minDuration * self.widthPerSecond;
    CGFloat maxX = CMTimeGetSeconds([self.asset duration]) <= self.maxDuration + 0.5 ? CGRectGetMaxX(self.framesView.frame) : CGRectGetWidth(self.frame) - self.thumbWidth;
    if (newRightViewMidX - self.overlayWidth/2 < minX) {
        newRightViewMidX = minX + self.overlayWidth/2;
    } else if (newRightViewMidX - self.overlayWidth/2 > maxX) {
        newRightViewMidX = maxX + self.overlayWidth/2;
    }
    
    return newRightViewMidX;
}

- (void)notifyDelegateOfDidChange
{
    
    NSTimeInterval start = [self offsetToTime:CGRectGetMaxX(self.leftOverlayView.frame)];
    NSTimeInterval end = [self offsetToTime:CGRectGetMinX(self.rightOverlayView.frame)];
    
    if (start==_startTime && end==_endTime){
        // thumb events may fire multiple times with the same value, so we detect them and ignore them.
        //        NSLog(@"no change");
        return;
    }
    BOOL movedLeft = (end == _endTime);
    
    _startTime = start;
    _endTime = end;
    
    if([self.delegate respondsToSelector:@selector(trimmerView:didChangeLeftPosition:rightPosition:offset:movedLeft:)])
    {
        [self.delegate trimmerView:self
             didChangeLeftPosition:_startTime
                     rightPosition:_endTime
                            offset:self.scrollView.contentOffset.x
                         movedLeft:movedLeft];
    }
}

-(void) notifyDelegateOfEndEditing
{
    if([self.delegate respondsToSelector:@selector(trimmerViewDidEndEditing:)])
    {
        [self.delegate trimmerViewDidEndEditing:self];
    }
}

-(CGFloat)timeToOffset:(NSTimeInterval) time {
    return time * self.widthPerSecond + self.thumbWidth - self.scrollView.contentOffset.x;
}

-(NSTimeInterval)offsetToTime:(CGFloat) offset {
    return (offset - self.thumbWidth + self.scrollView.contentOffset.x) / self.widthPerSecond;
}


- (void)addFrames
{
    if (! self.asset)
        return;
    self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.asset];
    self.imageGenerator.appliesPreferredTrackTransform = YES;
    CGFloat scale = [UIScreen mainScreen].scale;
    self.imageGenerator.maximumSize = CGSizeMake(CGRectGetWidth(self.framesView.frame) * scale,
                                                 CGRectGetHeight(self.framesView.frame) * scale);
    
    CGFloat picWidth = 0;
    
    // First image
    NSError *error;
    CMTime actualTime;
    CGImageRef firstImage = [self.imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:&actualTime error:&error];
    UIImage *videoScreen;
    videoScreen = [[UIImage alloc] initWithCGImage:firstImage scale:scale orientation:UIImageOrientationUp];
    
    if (error == nil && firstImage != NULL) {
        picWidth = videoScreen.size.width;
    } else {
        return;
    }
    
    Float64 duration = CMTimeGetSeconds([self.asset duration]);
    CGFloat allFramesWidth = CGRectGetWidth(self.frame) - 2 * self.thumbWidth; // quick fix to make up for the width of thumb views
    
    double temporalFactor = MAX(1.0, (duration / self.maxDuration));
    CGFloat frameViewFrameWidth = temporalFactor * allFramesWidth;
    self.widthPerSecond = frameViewFrameWidth / duration;

    [self.framesView setFrame:CGRectMake(self.thumbWidth, 0, frameViewFrameWidth, CGRectGetHeight(self.framesView.frame))];
    CGFloat contentViewFrameWidth = duration <= self.maxDuration + 0.5 ? self.bounds.size.width : frameViewFrameWidth + 2 * self.thumbWidth;
    [self.contentView setFrame:CGRectMake(0, 0, contentViewFrameWidth, CGRectGetHeight(self.contentView.frame))];
    [self.scrollView setContentSize:self.contentView.frame.size];
    
    NSInteger actualFramesNeeded = ceil((temporalFactor * allFramesWidth) / picWidth);
    
    Float64 durationPerFrame = duration / (actualFramesNeeded * 1.0);
    
    NSMutableArray *times = [[NSMutableArray alloc] initWithCapacity:actualFramesNeeded];
    for (int i=0; i<actualFramesNeeded; i++) {
        
        CMTime time = CMTimeMakeWithSeconds( (((double)i) + 0.5) * durationPerFrame, 600);
        [times addObject:[NSValue valueWithCMTime:time]];
        
        CGRect frame = CGRectMake(i*picWidth, 0, picWidth, self.framesView.frame.size.height);
        UIImageView *tmp = [[UIImageView alloc] initWithFrame:frame];
        tmp.tag = i + 1;
        [self.framesView addSubview:tmp];
    }
    
    [self.imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable cgImageRef, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        
        if(result == AVAssetImageGeneratorSucceeded){
            
            int tag = -1;
            
            for(int i = 0 ; i < [times count]; i++){
                CMTime time = [[times objectAtIndex:i] CMTimeValue];
                if(CMTimeCompare(time , requestedTime) == 0){
                    tag = i + 1;
                    break;
                }
            }
            
            if (tag > 0) {
                UIImage *shot;
                shot = [[UIImage alloc] initWithCGImage:cgImageRef scale:scale orientation:UIImageOrientationUp];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIImageView *imageView = (UIImageView *)[self.framesView viewWithTag:tag];
                    [imageView setImage:shot];
                });
            }
        }
    }];
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (CMTimeGetSeconds([self.asset duration]) <= self.maxDuration + 0.5) {
        [UIView animateWithDuration:0.3 animations:^{
            [scrollView setContentOffset:CGPointZero];
        }];
    }
    [self notifyDelegateOfDidChange];
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self notifyDelegateOfEndEditing];
}


@end
