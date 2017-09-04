
//	Copyright 2005-2017 Michel Fortin
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.

#import "ViewController.h"
#import "AppDelegate.h"

#import <QuartzCore/QuartzCore.h>
#import "CapturePipeline.h"
#import "OpenGLPixelBufferView.h"

@interface ViewController () <CapturePipelineDelegate, UIAlertViewDelegate>
{
	BOOL _addedObservers;
	BOOL _allowedToUseGPU;
	BOOL _mainCameraUIAdapted;
	BOOL _presentingShareView;
}

@property(nonatomic, strong) IBOutlet UIBarButtonItem *photoButton;
@property(nonatomic, strong) IBOutlet UIBarButtonItem *flashButton;
@property(nonatomic, strong) IBOutlet UIBarButtonItem *shareButton;
@property(nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property(nonatomic, strong) IBOutlet UILabel *framerateLabel;
@property(nonatomic, strong) IBOutlet UILabel *dimensionsLabel;
@property(nonatomic, strong) IBOutlet UIView *contentView;
@property(nonatomic, strong) IBOutlet UIView *noCameraPermissionOverlayView;
@property(nonatomic, strong) NSTimer *labelTimer;
@property(nonatomic, strong) OpenGLPixelBufferView *previewView;
@property(nonatomic, strong) CapturePipeline *capturePipeline;

@property(nonatomic, strong) AVCaptureDevice *videoDevice;

@end

@implementation ViewController

- (void)dealloc
{
	if ( _addedObservers ) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:[UIApplication sharedApplication]];
		[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
	}
}

#pragma mark - View lifecycle

- (void)applicationDidEnterBackground
{
	// Avoid using the GPU in the background
	_allowedToUseGPU = NO;
	self.capturePipeline.renderingEnabled = NO;

	 // We reset the OpenGLPixelBufferView to ensure all resources have been clear when going to the background.
	[self.previewView reset];
}

- (void)didReceiveMemoryWarning
{
	[self.previewView reset];
	[super didReceiveMemoryWarning];
}

- (void)applicationWillEnterForeground
{
	_allowedToUseGPU = YES;
	self.capturePipeline.renderingEnabled = !_presentingShareView;
}

- (void)viewDidLoad
{
    self.capturePipeline = [[CapturePipeline alloc] init];
	[self.capturePipeline setDelegate:self callbackQueue:dispatch_get_main_queue()];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationDidEnterBackground)
												 name:UIApplicationDidEnterBackgroundNotification
											   object:[UIApplication sharedApplication]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationWillEnterForeground)
												 name:UIApplicationWillEnterForegroundNotification
											   object:[UIApplication sharedApplication]];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(adjustOrientation)
												 name:UIApplicationDidChangeStatusBarOrientationNotification
											   object:[UIApplication sharedApplication]];

    // Keep track of changes to the device orientation so we can update the capture pipeline
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	
	_addedObservers = YES;
	
	// the willEnterForeground and didEnterBackground notifications are subsequently used to update _allowedToUseGPU
	_allowedToUseGPU = ( [UIApplication sharedApplication].applicationState != UIApplicationStateBackground );
	self.capturePipeline.renderingEnabled = _allowedToUseGPU && !_presentingShareView;

    [super viewDidLoad];
	
	[self checkCameraPrivacySettings];

	// Adapt UI for default device (will be called again when capture session starts)
	[self setVideoDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]];
}

- (void)setVideoDevice:(AVCaptureDevice *)videoDevice
{
	_videoDevice = videoDevice;

	if (_mainCameraUIAdapted == NO)
	{
#if TARGET_IPHONE_SIMULATOR
		if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
#endif
		if (!videoDevice.hasTorch)
		{
			// remove torch button if main camera does not have it
			NSMutableArray *items = self.toolbar.items.mutableCopy;
			[items removeObjectAtIndex:0];
			[items removeObjectAtIndex:0];
			self.toolbar.items = items;
		}
		_mainCameraUIAdapted = YES;
	}

	self.flashButton.enabled = videoDevice.torchAvailable;
#if TARGET_IPHONE_SIMULATOR
	self.flashButton.enabled = YES;
#endif
	[self reflectTorchActiveState:videoDevice.torchActive];
}

- (void)reflectTorchActiveState:(BOOL)torchActive
{
	NSString *torchImageName = torchActive ? @"FlashLight" : @"FlashDark";
	UIImage *torchImage = [UIImage imageNamed:torchImageName];
	self.flashButton.image = torchImage;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	[self.capturePipeline startRunning];

	self.labelTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateLabels) userInfo:nil repeats:YES];

#if TARGET_IPHONE_SIMULATOR
	// wait after autolayout did its work
	[self setupPreviewView];
	// display some test image
//	[self.previewView displayImage:[UIImage imageWithContentsOfFile:@"test-image.jpg"]];
#endif
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	[self.labelTimer invalidate];
	self.labelTimer = nil;
	
	[self.capturePipeline stopRunning];
	[UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

#pragma mark - UI

- (IBAction)toggleShowFramerate:(UIGestureRecognizer *)gestureRecognizer
{
	switch (gestureRecognizer.state)
	{
		case UIGestureRecognizerStateBegan:
			self.framerateLabel.hidden = !self.framerateLabel.hidden;
			self.dimensionsLabel.hidden = !self.dimensionsLabel.hidden;
			break;
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
		case UIGestureRecognizerStateFailed:
			//self.framerateLabel.hidden = YES;
			//self.dimensionsLabel.hidden = YES;
			break;
		case UIGestureRecognizerStateChanged:
		case UIGestureRecognizerStatePossible:
			break;
	}
}

- (IBAction)zoom:(UIPinchGestureRecognizer *)gestureRecognizer
{
	NSError *error;
	switch (gestureRecognizer.state)
	{
		case UIGestureRecognizerStateBegan:
			[_videoDevice lockForConfiguration:&error];
			gestureRecognizer.scale = _videoDevice.videoZoomFactor;
			break;
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
		case UIGestureRecognizerStateFailed:
			[_videoDevice unlockForConfiguration];
			break;
		case UIGestureRecognizerStateChanged:
		{
			CGFloat factor = gestureRecognizer.scale;
			CGFloat minFactor = 1;
			CGFloat maxFactor = MIN(_videoDevice.activeFormat.videoZoomFactorUpscaleThreshold*2, _videoDevice.activeFormat.videoMaxZoomFactor);
			_videoDevice.videoZoomFactor = MIN(maxFactor, MAX(minFactor, factor));
			break;
		}
		case UIGestureRecognizerStatePossible:
			break;
	}
}

- (IBAction)toggleInputDevice:(id)sender
{
	if (_presentingShareView) {
		return;
	}
	BOOL changed = [self.capturePipeline toggleInputDevice];
	if (changed)
	{
		[self.previewView reset];
		self.previewView.alpha = 0;
		self.flashButton.enabled = NO;
		[self reflectTorchActiveState:NO];
		[UIView transitionFromView:self.contentView toView:self.contentView duration:0.5 options:UIViewAnimationOptionTransitionFlipFromRight|UIViewAnimationOptionAllowAnimatedContent|UIViewAnimationOptionShowHideTransitionViews completion:^(BOOL success){
			[UIView animateWithDuration:0.2 animations:^{
				self.previewView.alpha = 1;
			}];
		}];
	}
}

- (IBAction)toggleTorch:(id)sender
{
	NSError *error = nil;
	if ([_videoDevice lockForConfiguration:&error])
	{
		BOOL torchActive = !_videoDevice.torchActive;
		[_videoDevice setTorchMode:torchActive ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
		[_videoDevice unlockForConfiguration];
		[self reflectTorchActiveState:torchActive];
	}
	else
		NSLog(@"videoDevice lockForConfiguration returned error %@", error);
}

- (IBAction)showSettings:(id)sender {
	UIViewController *vc = [[UIStoryboard storyboardWithName:@"Options" bundle:nil] instantiateInitialViewController];
	vc.view.tintColor = self.view.tintColor;
	[self presentViewController:vc animated:YES completion:nil];
}

- (void)setupPreviewView
{
    // Set up GL view
    self.previewView = [[OpenGLPixelBufferView alloc] initWithFrame:CGRectZero];
	self.previewView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

	[self adjustOrientation];

    [self.contentView insertSubview:self.previewView atIndex:0];
    CGRect bounds = CGRectZero;
    bounds.size = [self.contentView convertRect:self.contentView.bounds toView:self.previewView].size;
    self.previewView.bounds = bounds;
    self.previewView.center = CGPointMake(self.contentView.bounds.size.width/2.0, self.contentView.bounds.size.height/2.0);
}

- (void)checkCameraPrivacySettings
{
	[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.noCameraPermissionOverlayView.hidden = granted;
		});
	}];
}

- (void)updateLabels
{	
	NSString *frameRateString = [NSString stringWithFormat:@"%d FPS", (int)roundf(self.capturePipeline.videoFrameRate)];
	self.framerateLabel.text = frameRateString;
	
	NSString *dimensionsString = [NSString stringWithFormat:@"%d x %d", self.capturePipeline.videoDimensions.width, self.capturePipeline.videoDimensions.height];
	self.dimensionsLabel.text = dimensionsString;
}

- (void)showError:(NSError *)error
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:error.localizedDescription
														message:error.localizedFailureReason
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
}

- (IBAction)showCameraPrivacySettings:(id)sender
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}

#pragma mark - RosyWriterCapturePipelineDelegate

- (void)capturePipeline:(CapturePipeline *)capturePipeline didStartRunningWithVideoDevice:(AVCaptureDevice *)videoDevice
{
	self.videoDevice = videoDevice;
	[self adjustOrientation];
}

- (void)adjustOrientation {
	UIInterfaceOrientation currentInterfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
	self.previewView.transform = [self.capturePipeline transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)currentInterfaceOrientation withAutoMirroring:NO]; // Front camera preview should be mirrored
	BOOL mirrored = self.videoDevice.position == AVCaptureDevicePositionFront;
	self.previewView.mirrorTransform = mirrored;
	self.previewView.frame = self.previewView.superview.bounds;

	// capture orientation must compensate for the transform that was applied
	switch (currentInterfaceOrientation) {
		case UIInterfaceOrientationUnknown:
		case UIInterfaceOrientationPortrait: self.previewView.captureOrientation = !mirrored ?
			UIImageOrientationLeftMirrored :
			UIImageOrientationRightMirrored;
			break;
		case UIInterfaceOrientationPortraitUpsideDown: self.previewView.captureOrientation = !mirrored ?
			UIImageOrientationRightMirrored :
			UIImageOrientationLeftMirrored;
			break;
		case UIInterfaceOrientationLandscapeLeft: self.previewView.captureOrientation = !mirrored ?
			UIImageOrientationUpMirrored :
			UIImageOrientationDownMirrored;
			break;
		case UIInterfaceOrientationLandscapeRight: self.previewView.captureOrientation = !mirrored ?
			UIImageOrientationDownMirrored :
			UIImageOrientationUpMirrored;
			break;
	}
}

- (void)capturePipeline:(CapturePipeline *)capturePipeline didStopRunningWithError:(NSError *)error
{
	self.videoDevice = nil;

	[self showError:error];
	
	self.photoButton.enabled = NO;
}

// Preview
- (void)capturePipeline:(CapturePipeline *)capturePipeline previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer
{
	if ( ! _allowedToUseGPU ) {
		return;
	}
	
	if ( ! self.previewView ) {
		[self setupPreviewView];
	}

	self.noCameraPermissionOverlayView.hidden = YES;
	
	[self.previewView displayPixelBuffer:previewPixelBuffer];

	UIApplication *app = [UIApplication sharedApplication];
	BOOL shouldDisableIdleTimer = (self.presentedViewController == nil);
	if (app.idleTimerDisabled != shouldDisableIdleTimer)
		app.idleTimerDisabled = shouldDisableIdleTimer;
}

- (void)capturePipelineDidRunOutOfPreviewBuffers:(CapturePipeline *)capturePipeline
{
	if ( _allowedToUseGPU ) {
		[self.previewView flushPixelBufferCache];
	}
}

- (IBAction)sharePicture:(UIBarButtonItem *)item {
	UIImage *image = [self.previewView captureCurrentImage];
	if (image == nil) return;
	BOOL torchActive = NO;
	if (_videoDevice.hasTorch && [_videoDevice lockForConfiguration:nil])
	{
		torchActive = _videoDevice.torchActive;
		[_videoDevice setTorchMode:AVCaptureTorchModeOff];
		[_videoDevice unlockForConfiguration];
		[self reflectTorchActiveState:torchActive];
	}
	_presentingShareView = YES;
	self.capturePipeline.renderingEnabled = !_presentingShareView; // freeze image
	UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[image] applicationActivities:nil];
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		activityViewController.modalPresentationStyle = UIModalPresentationPopover;
		activityViewController.popoverPresentationController.barButtonItem = item;
	}
	[self presentViewController:activityViewController animated:YES completion:nil];
	activityViewController.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError){
		_presentingShareView = NO;
		self.capturePipeline.renderingEnabled = !_presentingShareView; // unfreeze image
		if (torchActive && _videoDevice.hasTorch && [_videoDevice lockForConfiguration:nil])
		{
			[_videoDevice setTorchMode:torchActive ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
			[_videoDevice unlockForConfiguration];
			[self reflectTorchActiveState:torchActive];
		}
	};
}

@end
