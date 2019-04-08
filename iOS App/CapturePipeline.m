
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

// Based on the RosyWriter sample code

#import "CapturePipeline.h"

@import UIKit;
@import CoreMedia;
@import AssetsLibrary;
@import ImageIO;

/*
 RETAINED_BUFFER_COUNT is the number of pixel buffers we expect to hold on to from the renderer. This value informs the renderer how to size its buffer pool and how many pixel buffers to preallocate (done in the prepareWithOutputDimensions: method). Preallocation helps to lessen the chance of frame drops in our recording, in particular during recording startup. If we try to hold on to more buffers than RETAINED_BUFFER_COUNT then the renderer will fail to allocate new buffers from its pool and we will drop frames.

 A back of the envelope calculation to arrive at a RETAINED_BUFFER_COUNT of '6':
 - The preview path only has the most recent frame, so this makes the movie recording path the long pole.
 - The movie recorder internally does a dispatch_async to avoid blocking the caller when enqueuing to its internal asset writer.
 - Allow 2 frames of latency to cover the dispatch_async and the -[AVAssetWriterInput appendSampleBuffer:] call.
 - Then we allow for the encoder to retain up to 4 frames. Two frames are retained while being encoded/format converted, while the other two are to handle encoder format conversion pipelining and encoder startup latency.

 Really you need to test and measure the latency in your own application pipeline to come up with an appropriate number. 1080p BGRA buffers are quite large, so it's a good idea to keep this number as low as possible.
 */

#define RETAINED_BUFFER_COUNT 0

#define LOG_STATUS_TRANSITIONS 0

@interface CapturePipeline () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
	__weak id <CapturePipelineDelegate> _delegate; // __weak doesn't actually do anything under non-ARC
	dispatch_queue_t _delegateCallbackQueue;
	
	NSMutableArray *_previousSecondTimestamps;

	AVCaptureSession *_captureSession;
	AVCaptureDevice *_videoDevice;
	AVCaptureConnection *_videoConnection;
	BOOL _running;
	BOOL _startCaptureSessionOnEnteringForeground;
	id _applicationWillEnterForegroundNotificationObserver;
	NSDictionary *_videoCompressionSettings;

	dispatch_queue_t _sessionQueue;
	dispatch_queue_t _videoDataOutputQueue;
	
	BOOL _renderingEnabled;
	
	UIBackgroundTaskIdentifier _pipelineRunningTask;
}

@property(nonatomic, retain) __attribute__((NSObject)) CVPixelBufferRef currentPreviewPixelBuffer;

@property(readwrite) float videoFrameRate;
@property(readwrite) CMVideoDimensions videoDimensions;
@property(nonatomic, readwrite) AVCaptureVideoOrientation videoOrientation;

@property(nonatomic, retain) __attribute__((NSObject)) CMFormatDescriptionRef outputVideoFormatDescription;

@end

@implementation CapturePipeline

- (instancetype)init
{
	self = [super init];
	if ( self )
	{
		_previousSecondTimestamps = [[NSMutableArray alloc] init];

		_sessionQueue = dispatch_queue_create( "com.apple.sample.capturepipeline.session", DISPATCH_QUEUE_SERIAL );
		
		// In a multi-threaded producer consumer system it's generally a good idea to make sure that producers do not get starved of CPU time by their consumers.
		// In this app we start with VideoDataOutput frames on a high priority queue, and downstream consumers use default priority queues.
		// Audio uses a default priority queue because we aren't monitoring it live and just want to get it into the movie.
		// AudioDataOutput can tolerate more latency than VideoDataOutput as its buffers aren't allocated out of a fixed size pool.
		_videoDataOutputQueue = dispatch_queue_create( "com.apple.sample.capturepipeline.video", DISPATCH_QUEUE_SERIAL );
		dispatch_set_target_queue( _videoDataOutputQueue, dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ) );

		_pipelineRunningTask = UIBackgroundTaskInvalid;
	}
	return self;
}

- (void)dealloc
{
	if ( _currentPreviewPixelBuffer ) {
		CFRelease( _currentPreviewPixelBuffer );
	}
	
	[self teardownCaptureSession];
	
	if ( _outputVideoFormatDescription ) {
		CFRelease( _outputVideoFormatDescription );
	}
}

#pragma mark Delegate

- (void)setDelegate:(id<CapturePipelineDelegate>)delegate callbackQueue:(dispatch_queue_t)delegateCallbackQueue // delegate is weak referenced
{
	if ( delegate && ( delegateCallbackQueue == NULL ) ) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Caller must provide a delegateCallbackQueue" userInfo:nil];
	}
	
	@synchronized( self )
	{
		_delegate = delegate; // unnecessary under ARC, just assign to _delegate directly
		if ( delegateCallbackQueue != _delegateCallbackQueue ) {
			_delegateCallbackQueue = delegateCallbackQueue;
		}
	}
}

- (id<CapturePipelineDelegate>)delegate
{
	id <CapturePipelineDelegate> delegate = nil;
	@synchronized( self ) {
		delegate = _delegate; // unnecessary under ARC, just assign delegate to _delegate directly
	}
	return delegate;
}

#pragma mark Capture Session

- (void)_startRunningCaptureSession {
	[_captureSession startRunning];

	@synchronized( self ) 
	{
		if (self.delegate)
		{
			dispatch_async(_delegateCallbackQueue, ^{
				@autoreleasepool {
					[self.delegate capturePipeline:self didStartRunningWithVideoDevice:self->_videoDevice];
				}
			});
		}
	}
}

- (void)startRunning
{
#if TARGET_IPHONE_SIMULATOR
#else
	dispatch_sync( _sessionQueue, ^{
		[self setupCaptureSession];

		[self _startRunningCaptureSession];
		self->_running = YES;
	} );
#endif
}

- (void)stopRunning
{
#if TARGET_IPHONE_SIMULATOR
#else
	dispatch_sync( _sessionQueue, ^{
		self->_running = NO;
		
		[self->_captureSession stopRunning];
		
		[self captureSessionDidStopRunning];
		
		[self teardownCaptureSession];
	} );
#endif
}

- (void)setupCaptureSession
{
	if ( _captureSession ) {
		return;
	}
	
	_captureSession = [[AVCaptureSession alloc] init];	

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionNotification:) name:nil object:_captureSession];
	_applicationWillEnterForegroundNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication] queue:nil usingBlock:^(NSNotification *note) {
		// Retain self while the capture session is alive by referencing it in this observer block which is tied to the session lifetime
		// Client must stop us running before we can be deallocated
		[self applicationWillEnterForeground];
	}];
	
	/* Video */
	if (_videoDevice == nil)
		_videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *videoIn = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:nil];
	if ( [_captureSession canAddInput:videoIn] ) {
		[_captureSession addInput:videoIn];
	}
	
	AVCaptureVideoDataOutput *videoOut = [[AVCaptureVideoDataOutput alloc] init];
	videoOut.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
	[videoOut setSampleBufferDelegate:self queue:_videoDataOutputQueue];
	
	// RosyWriter records videos and we prefer not to have any dropped frames in the video recording.
	// By setting alwaysDiscardsLateVideoFrames to NO we ensure that minor fluctuations in system load or in our processing time for a given frame won't cause framedrops.
	// We do however need to ensure that on average we can process frames in realtime.
	// If we were doing preview only we would probably want to set alwaysDiscardsLateVideoFrames to YES.
	videoOut.alwaysDiscardsLateVideoFrames = NO;
	
	if ( [_captureSession canAddOutput:videoOut] ) {
		[_captureSession addOutput:videoOut];
	}
	_videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
		
	int frameRate;
	NSString *sessionPreset = AVCaptureSessionPresetPhoto;
	CMTime frameDuration = kCMTimeInvalid;
	// For single core systems like iPhone 4 and iPod Touch 4th Generation we use a lower resolution and framerate to maintain real-time performance.
	if ( [NSProcessInfo processInfo].processorCount == 1 )
	{
		if ( [_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480] ) {
			sessionPreset = AVCaptureSessionPreset640x480;
		}
		frameRate = 15;
	}
	else
	{
#if ! USE_OPENGL_RENDERER
		// When using the CPU renderers or the CoreImage renderer we lower the resolution to 720p so that all devices can maintain real-time performance (this is primarily for A5 based devices like iPhone 4s and iPod Touch 5th Generation).
		if ( [_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720] ) {
			sessionPreset = AVCaptureSessionPreset1280x720;
		}
#endif // ! USE_OPENGL_RENDERER

		frameRate = 30;
	}
	
	_captureSession.sessionPreset = sessionPreset;
	
	frameDuration = CMTimeMake( 1, frameRate );

	NSError *error = nil;
	if ( [_videoDevice lockForConfiguration:&error] ) {
		_videoDevice.activeVideoMaxFrameDuration = frameDuration;
		_videoDevice.activeVideoMinFrameDuration = frameDuration;
		[_videoDevice unlockForConfiguration];
	}
	else {
		NSLog( @"videoDevice lockForConfiguration returned error %@", error );
	}

	// Get the recommended compression settings after configuring the session/device.
	_videoCompressionSettings = [[videoOut recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeQuickTimeMovie] copy];
	
	self.videoOrientation = _videoConnection.videoOrientation;
	
	return;
}

- (void)teardownCaptureSession
{
	if ( _captureSession )
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:_captureSession];
		
		[[NSNotificationCenter defaultCenter] removeObserver:_applicationWillEnterForegroundNotificationObserver];
		_applicationWillEnterForegroundNotificationObserver = nil;
		
		_captureSession = nil;
		
		_videoCompressionSettings = nil;
	}
}

- (void)captureSessionNotification:(NSNotification *)notification
{
	dispatch_async( _sessionQueue, ^{
		
		if ( [notification.name isEqualToString:AVCaptureSessionWasInterruptedNotification] )
		{
			NSLog( @"session interrupted, reason: %@", notification.userInfo[AVCaptureSessionInterruptionReasonKey] );

			// Since we can't resume running while in the background we need to remember this for next time we come to the foreground
			if ( self->_running ) {
				self->_startCaptureSessionOnEnteringForeground = YES;
			}
			
			[self captureSessionDidStopRunning];
		}
		else if ( [notification.name isEqualToString:AVCaptureSessionInterruptionEndedNotification] )
		{
			NSLog( @"session interruption ended" );
		}
		else if ( [notification.name isEqualToString:AVCaptureSessionRuntimeErrorNotification] )
		{
			[self captureSessionDidStopRunning];
			
			NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
			if ( error.code == AVErrorMediaServicesWereReset )
			{
				NSLog( @"media services were reset" );
				[self handleRecoverableCaptureSessionRuntimeError:error];
			}
			else
			{
				[self handleNonRecoverableCaptureSessionRuntimeError:error];
			}
		}
		else if ( [notification.name isEqualToString:AVCaptureSessionDidStartRunningNotification] )
		{
			NSLog( @"session started running" );
		}
		else if ( [notification.name isEqualToString:AVCaptureSessionDidStopRunningNotification] )
		{
			NSLog( @"session stopped running" );
		}
	} );
}

- (void)handleRecoverableCaptureSessionRuntimeError:(NSError *)error
{
	if ( _running ) {
		[self _startRunningCaptureSession];
	}
}

- (void)handleNonRecoverableCaptureSessionRuntimeError:(NSError *)error
{
	NSLog( @"fatal runtime error %@, code %i", error, (int)error.code );
	
	_running = NO;
	[self teardownCaptureSession];
	
	@synchronized( self ) 
	{
		if ( self.delegate ) {
			dispatch_async( _delegateCallbackQueue, ^{
				@autoreleasepool {
					[self.delegate capturePipeline:self didStopRunningWithError:error];
				}
			});
		}
	}
}

- (void)captureSessionDidStopRunning
{
	[self teardownVideoPipeline];
}

- (void)applicationWillEnterForeground
{
	NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
	
	dispatch_sync( _sessionQueue, ^{
		if ( self->_startCaptureSessionOnEnteringForeground ) {
			NSLog( @"-[%@ %@] manually restarting session", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
			
			self->_startCaptureSessionOnEnteringForeground = NO;
			if ( self->_running ) {
				[self _startRunningCaptureSession];
			}
		}
	} );
}

#pragma mark Capture Pipeline

- (void)setupVideoPipelineWithInputFormatDescription:(CMFormatDescriptionRef)inputFormatDescription
{
	NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
	
	[self videoPipelineWillStartRunning];
	
	self.videoDimensions = CMVideoFormatDescriptionGetDimensions( inputFormatDescription );
	self.outputVideoFormatDescription = inputFormatDescription;
}

// synchronous, blocks until the pipeline is drained, don't call from within the pipeline
- (void)teardownVideoPipeline
{
	// The session is stopped so we are guaranteed that no new buffers are coming through the video data output.
	// There may be inflight buffers on _videoDataOutputQueue however.
	// Synchronize with that queue to guarantee no more buffers are in flight.
	// Once the pipeline is drained we can tear it down safely.

	NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
	
	dispatch_sync( _videoDataOutputQueue, ^{
		if ( ! self.outputVideoFormatDescription ) {
			return;
		}
		
		self.outputVideoFormatDescription = nil;
		self.currentPreviewPixelBuffer = NULL;
		
		NSLog( @"-[%@ %@] finished teardown", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
		
		[self videoPipelineDidFinishRunning];
	} );
}

- (void)videoPipelineWillStartRunning
{
	NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
	
	NSAssert( _pipelineRunningTask == UIBackgroundTaskInvalid, @"should not have a background task active before the video pipeline starts running" );
	
	_pipelineRunningTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
		NSLog( @"video capture pipeline background task expired" );
	}];
}

- (void)videoPipelineDidFinishRunning
{
	NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
	
	NSAssert( _pipelineRunningTask != UIBackgroundTaskInvalid, @"should have a background task active when the video pipeline finishes running" );
	
	[[UIApplication sharedApplication] endBackgroundTask:_pipelineRunningTask];
	_pipelineRunningTask = UIBackgroundTaskInvalid;
}

// call under @synchronized( self )
- (void)videoPipelineDidRunOutOfBuffers
{
	// We have run out of buffers.
	// Tell the delegate so that it can flush any cached buffers.
	if ( self.delegate ) {
		dispatch_async( _delegateCallbackQueue, ^{
			@autoreleasepool {
				[self.delegate capturePipelineDidRunOutOfPreviewBuffers:self];
			}
		} );
	}
}

- (void)setRenderingEnabled:(BOOL)renderingEnabled
{
	@synchronized( self ) {
		_renderingEnabled = renderingEnabled;
	}
}

- (BOOL)renderingEnabled
{
	@synchronized( self ) {
		return _renderingEnabled;
	}
}

// call under @synchronized( self )
- (void)outputPreviewPixelBuffer:(CVPixelBufferRef)previewPixelBuffer
{
	if ( self.delegate )
	{
		// Keep preview latency low by dropping stale frames that have not been picked up by the delegate yet
		self.currentPreviewPixelBuffer = previewPixelBuffer;
		
		dispatch_async( _delegateCallbackQueue, ^{
			@autoreleasepool
			{
				CVPixelBufferRef currentPreviewPixelBuffer = NULL;
				@synchronized( self )
				{
					currentPreviewPixelBuffer = self.currentPreviewPixelBuffer;
					if ( currentPreviewPixelBuffer ) {
						CFRetain( currentPreviewPixelBuffer );
						self.currentPreviewPixelBuffer = NULL;
					}
				}
				
				if ( currentPreviewPixelBuffer ) {
					[self.delegate capturePipeline:self previewPixelBufferReadyForDisplay:currentPreviewPixelBuffer];
					CFRelease( currentPreviewPixelBuffer );
				}
			}
		} );
	}
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
	CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription( sampleBuffer );
	
	if ( connection == _videoConnection )
	{
		if ( self.outputVideoFormatDescription == nil ) {
			// Don't render the first sample buffer.
			// This gives us one frame interval (33ms at 30fps) for setupVideoPipelineWithInputFormatDescription: to complete.
			// Ideally this would be done asynchronously to ensure frames don't back up on slower devices.
			[self setupVideoPipelineWithInputFormatDescription:formatDescription];
		}
		else {
			[self renderVideoSampleBuffer:sampleBuffer];
		}
	}
}

- (void)renderVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	CVPixelBufferRef renderedPixelBuffer = NULL;
	CMTime timestamp = CMSampleBufferGetPresentationTimeStamp( sampleBuffer );
	
	[self calculateFramerateAtTimestamp:timestamp];
	
	// We must not use the GPU while running in the background.
	// setRenderingEnabled: takes the same lock so the caller can guarantee no GPU usage once the setter returns.
	@synchronized( self )
	{
		if ( _renderingEnabled ) {
			CVPixelBufferRef sourcePixelBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
			renderedPixelBuffer = (CVPixelBufferRef)CFRetain(sourcePixelBuffer);
		}
		else {
			return;
		}

		if ( renderedPixelBuffer )
		{
			[self outputPreviewPixelBuffer:renderedPixelBuffer];

			CFRelease( renderedPixelBuffer );
		}
		else
		{
			[self videoPipelineDidRunOutOfBuffers];
		}
	}
}

- (BOOL)inputDeviceCount
{
	return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count;
}

- (BOOL)toggleInputDevice
{
	AVCaptureDevice *currentVideoDevice = _videoDevice;
	AVCaptureDevice *nextVideoDevice = nil;
	BOOL passedCurrent = NO;

	for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if (device == currentVideoDevice)
		{
			passedCurrent = YES;
			continue;
		}
		if (device.connected)
		{
			nextVideoDevice = device;
			if (passedCurrent)
				break;
		}
	}

	if (nextVideoDevice && nextVideoDevice != _videoDevice)
	{
		dispatch_async(_sessionQueue, ^{
			self->_videoDevice = nextVideoDevice;
			if (self->_running)
			{
				[self teardownCaptureSession];
#if USE_OPENGL_RENDERER
				[self teardownVideoPipeline];
				self.outputVideoFormatDescription = nil;
#endif
				[self setupCaptureSession];
				[self _startRunningCaptureSession];
			}
		});
		return YES;
	}
	return NO;
}

#pragma mark Utilities

// Auto mirroring: Front camera is mirrored; back camera isn't 
- (CGAffineTransform)transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)orientation withAutoMirroring:(BOOL)mirror
{
	CGAffineTransform transform = CGAffineTransformIdentity;
		
	// Calculate offsets from an arbitrary reference orientation (portrait)
	CGFloat orientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation( orientation );
	CGFloat videoOrientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation( self.videoOrientation );
	
	// Find the difference in angle between the desired orientation and the video orientation
	CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
	transform = CGAffineTransformMakeRotation( angleOffset );

	if ( _videoDevice.position == AVCaptureDevicePositionFront )
	{
		if ( mirror ) {
			transform = CGAffineTransformScale( transform, -1, 1 );
		}
	}
	
	return transform;
}

static CGFloat angleOffsetFromPortraitOrientationToOrientation(AVCaptureVideoOrientation orientation)
{
	CGFloat angle = 0.0;
	
	switch ( orientation )
	{
		case AVCaptureVideoOrientationPortrait:
			angle = 0.0;
			break;
		case AVCaptureVideoOrientationPortraitUpsideDown:
			angle = M_PI;
			break;
		case AVCaptureVideoOrientationLandscapeRight:
			angle = -M_PI_2;
			break;
		case AVCaptureVideoOrientationLandscapeLeft:
			angle = M_PI_2;
			break;
		default:
			break;
	}
	
	return angle;
}

- (void)calculateFramerateAtTimestamp:(CMTime)timestamp
{
	[_previousSecondTimestamps addObject:[NSValue valueWithCMTime:timestamp]];
	
	CMTime oneSecond = CMTimeMake( 1, 1 );
	CMTime oneSecondAgo = CMTimeSubtract( timestamp, oneSecond );
	
	while( CMTIME_COMPARE_INLINE( [_previousSecondTimestamps[0] CMTimeValue], <, oneSecondAgo ) ) {
		[_previousSecondTimestamps removeObjectAtIndex:0];
	}
	
	if ( [_previousSecondTimestamps count] > 1 ) {
		const Float64 duration = CMTimeGetSeconds( CMTimeSubtract( [[_previousSecondTimestamps lastObject] CMTimeValue], [_previousSecondTimestamps[0] CMTimeValue] ) );
		const float newRate = (float)( [_previousSecondTimestamps count] - 1 ) / duration;
		self.videoFrameRate = newRate;
	}
}

@end
