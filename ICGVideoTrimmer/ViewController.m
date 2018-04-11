//
//  ViewController.m
//  ICGVideoTrimmer
//
//  Created by HuongDo on 1/15/15.
//  Copyright (c) 2015 ichigo. All rights reserved.
//

#import "ViewController.h"
#import "ICGVideoTrimmerView.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, ICGVideoTrimmerDelegate>

@property (nonatomic, readonly) BOOL isPlaying;
@property (strong, nonatomic) AVPlayer *player;
//@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) NSTimer *playbackTimeCheckerTimer;
@property (assign, nonatomic) CGFloat videoPlaybackPosition;

@property (weak, nonatomic) IBOutlet ICGVideoTrimmerView *trimmerView;
@property (weak, nonatomic) IBOutlet UIButton *trimButton;
@property (weak, nonatomic) IBOutlet UIButton *changePositionButton;

@property (weak, nonatomic) IBOutlet UIView *videoPlayer;
@property (weak, nonatomic) IBOutlet UIView *videoLayer;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

@property (strong, nonatomic) NSString *tempVideoPath;
@property (strong, nonatomic) AVAssetExportSession *exportSession;
@property (strong, nonatomic) AVAsset *asset;

@property (assign, nonatomic) CGFloat startTime;
@property (assign, nonatomic) CGFloat stopTime;

@property (assign, nonatomic) BOOL restartOnPlay;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tempVideoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmpMov.mov"];

    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:nil];
    self.playerLayer.contentsGravity = AVLayerVideoGravityResizeAspect;

    [self.videoLayer.layer addSublayer:self.playerLayer];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnVideoLayer:)];
    [self.videoLayer addGestureRecognizer:tap];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewDidAppear:(BOOL)animated{
    [super  viewDidAppear:animated];
    self.asset = [AVAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"video" withExtension:@"mp4"]];
    //self.asset = [AVURLAsset assetWithURL:[NSURL URLWithStrin];
    [self loadAsset];

}

#pragma mark - ICGVideoTrimmerDelegate

- (void)trimmerView:(ICGVideoTrimmerView *)trimmerView
didChangeLeftPosition:(CGFloat)startTime
      rightPosition:(CGFloat)endTime
      offset:(CGFloat)offset {

    _restartOnPlay = YES;
    [self.player pause];
    //self.isPlaying = NO;
    [self stopPlaybackTimeChecker];

    //[self.trimmerView hideTracker:true];

    if (startTime != self.startTime) {
        //then it moved the left position, we should rearrange the bar
        [self seekVideoToPos:startTime];
    }
    else{ // right has changed
        [self seekVideoToPos:endTime];
    }
    self.startTime = startTime;
    self.stopTime = endTime;

    [self updateInfoStart:startTime end:endTime offset:offset];
}


#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSURL *url = [info objectForKey:UIImagePickerControllerMediaURL];
    self.asset = [AVAsset assetWithURL:url];
    [self loadAsset];
}

-(void)loadAsset {
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:self.asset];

    self.player = [AVPlayer playerWithPlayerItem:item];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    self.playerLayer.player = self.player;
    self.videoPlaybackPosition = 0;



    // set properties for trimmer view
    [self.trimmerView setThemeColor:[UIColor lightGrayColor]];
    [self.trimmerView setAsset:self.asset];
    [self.trimmerView setShowsRulerView:false];
    [self.trimmerView setRulerLabelInterval:10];
    [self.trimmerView setTrackerColor:[UIColor cyanColor]];
    [self.trimmerView setDelegate:self];
    CGFloat duration_seconds = CMTimeGetSeconds(self.asset.duration);

    self.trimmerView.maxLength = 17.5;
    self.trimmerView.minLength = 6.0;
    [self.trimmerView hideTracker:false];
    // important: reset subviews
    [self.trimmerView resetSubviews];
    self.trimmerView.endTime = duration_seconds;
    self.trimmerView.startTime = MAX(0.0, duration_seconds - 15.0);
    //[self.trimmerView setVideoBoundsToStartTime:duration_seconds-12.0
    //                                    endTime:duration_seconds
    //                                     offset:0.0];
    [self.trimButton setHidden:NO];
    [self.changePositionButton setHidden:NO];
}


#pragma mark - Actions

- (void)deleteTempFile
{
    NSURL *url = [NSURL fileURLWithPath:self.tempVideoPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL exist = [fm fileExistsAtPath:url.path];
    NSError *err;
    if (exist) {
        [fm removeItemAtURL:url error:&err];
        NSLog(@"file deleted");
        if (err) {
            NSLog(@"file remove error, %@", err.localizedDescription );
        }
    } else {
        NSLog(@"no file by that name");
    }
}

- (IBAction)selectAsset:(id)sender
{
    UIImagePickerController *myImagePickerController = [[UIImagePickerController alloc] init];
    myImagePickerController.sourceType =  UIImagePickerControllerSourceTypePhotoLibrary;
    myImagePickerController.mediaTypes =
    [[NSArray alloc] initWithObjects: (NSString *) kUTTypeMovie, nil];
    myImagePickerController.delegate = self;
    myImagePickerController.editing = NO;
    [self presentViewController:myImagePickerController animated:YES completion:nil];
}

- (IBAction)trimVideo:(id)sender
{
    [self deleteTempFile];
    
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:self.asset];
    if ([compatiblePresets containsObject:AVAssetExportPresetMediumQuality]) {
        
        self.exportSession = [[AVAssetExportSession alloc]
                              initWithAsset:self.asset presetName:AVAssetExportPresetPassthrough];
        // Implementation continues.
        
        NSURL *furl = [NSURL fileURLWithPath:self.tempVideoPath];
        
        self.exportSession.outputURL = furl;
        self.exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        
        CMTime start = CMTimeMakeWithSeconds(self.startTime, self.asset.duration.timescale);
        CMTime duration = CMTimeMakeWithSeconds(self.stopTime - self.startTime, self.asset.duration.timescale);
        CMTimeRange range = CMTimeRangeMake(start, duration);
        self.exportSession.timeRange = range;
        
        [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
            
            switch ([self.exportSession status]) {
                case AVAssetExportSessionStatusFailed:
                    
                    NSLog(@"Export failed: %@", [[self.exportSession error] localizedDescription]);
                    break;
                case AVAssetExportSessionStatusCancelled:
                    
                    NSLog(@"Export canceled");
                    break;
                default:
                    NSLog(@"NONE");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSURL *movieUrl = [NSURL fileURLWithPath:self.tempVideoPath];
                        UISaveVideoAtPathToSavedPhotosAlbum([movieUrl relativePath], self,@selector(video:didFinishSavingWithError:contextInfo:), nil);
                    });
                    
                    break;
            }
        }];
        
    }
}

- (IBAction)changeTrimPosition:(id)sender {
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Change position" message:@"You can change the trim position by manually entereing the start and end time" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        [textField setPlaceholder:@"Start time"];
        [textField setKeyboardType:UIKeyboardTypeDecimalPad];
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        [textField setPlaceholder:@"End time"];
        [textField setKeyboardType:UIKeyboardTypeDecimalPad];

    }];
    
    UIAlertAction * changeAction = [UIAlertAction actionWithTitle:@"Change" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString * startTimeString = alert.textFields.firstObject.text;
        NSString * endTimeString = alert.textFields.lastObject.text;
        double startTime = 0, endTime = CMTimeGetSeconds(self->_asset.duration);
        if([startTimeString length]>0)
            startTime = [alert.textFields.firstObject.text doubleValue];
        if([endTimeString length]>0)
              endTime = [alert.textFields.lastObject.text doubleValue];
        
        [self->_trimmerView setVideoBoundsToStartTime:startTime endTime:endTime offset:0.0];
        
        
    }];
    
    UIAlertAction * cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:changeAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
    
}


- (void)video:(NSString*)videoPath didFinishSavingWithError:(NSError*)error contextInfo:(void*)contextInfo {
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
                                                       delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)viewDidLayoutSubviews
{
    self.playerLayer.frame = CGRectMake(0, 0, self.videoLayer.frame.size.width, self.videoLayer.frame.size.height);
}

- (void)tapOnVideoLayer:(UITapGestureRecognizer *)tap
{
    if (self.isPlaying) {
        [self.player pause];
        [self stopPlaybackTimeChecker];
    }else {
        if (_restartOnPlay){
            [self seekVideoToPos: self.startTime];
            [self.trimmerView seekToTime:self.startTime animated:false];
            _restartOnPlay = NO;
        }
        [self.player play];
        [self startPlaybackTimeChecker];
    }

}

-(BOOL)isPlaying {
    return self.player.rate > 0;
}

- (void)startPlaybackTimeChecker
{
    [self stopPlaybackTimeChecker];
    
    self.playbackTimeCheckerTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(onPlaybackTimeCheckerTimer) userInfo:nil repeats:YES];
}

- (void)stopPlaybackTimeChecker
{
    if (self.playbackTimeCheckerTimer) {
        [self.playbackTimeCheckerTimer invalidate];
        self.playbackTimeCheckerTimer = nil;
    }
}

#pragma mark - PlaybackTimeCheckerTimer

- (void)onPlaybackTimeCheckerTimer
{
    CMTime curTime = [self.player currentTime];
    Float64 seconds = CMTimeGetSeconds(curTime);
    if (seconds < 0){
        seconds = 0; // this happens! dont know why.
    }
    self.videoPlaybackPosition = seconds;

    [self.trimmerView seekToTime:seconds animated:false];
    
    if (self.videoPlaybackPosition >= self.stopTime) {
        self.videoPlaybackPosition = self.startTime;
        [self seekVideoToPos: self.startTime];
        [self.trimmerView seekToTime:self.startTime animated:false];
    }
}

- (void)seekVideoToPos:(CGFloat)pos
{
    self.videoPlaybackPosition = pos;
    CMTime time = CMTimeMakeWithSeconds(self.videoPlaybackPosition, self.player.currentTime.timescale);
    //NSLog(@"seekVideoToPos time:%.2f", CMTimeGetSeconds(time));
    [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

-(void)trimmerView:(ICGVideoTrimmerView *)trimmerView didMoveTrackerToTime:(CGFloat)time {
    [self seekVideoToPos:time];
}

-(void) updateInfoStart:(double)start end:(double)end offset:(double)off {
    self.infoLabel.text = [NSString stringWithFormat:@"start: % 5.2f end: % 5.2f. D % 5.2f, O % 5.2f", start, end, end-start, off];
}
@end
