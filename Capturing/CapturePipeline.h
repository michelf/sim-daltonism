
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

@import Foundation;
@import AVFoundation;

@protocol CapturePipelineDelegate;

@interface CapturePipeline : NSObject

- (void)setDelegate:(id<CapturePipelineDelegate>)delegate callbackQueue:(dispatch_queue_t)delegateCallbackQueue; // delegate is weak referenced

// These methods are synchronous
@property (getter=isRunning, readonly) BOOL running;
- (void)startRunning;
- (void)stopRunning;

- (BOOL)selectDevice:(AVCaptureDevice *)newVideoDevice;
@property(readonly) AVCaptureDevice *videoDevice;

@property(readwrite) BOOL renderingEnabled; // When set to false the GPU will not be used after the setRenderingEnabled: call returns.

- (CGAffineTransform)transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)orientation withAutoMirroring:(BOOL)mirroring; // only valid after startRunning has been called

// Stats
@property(readonly) float videoFrameRate;
@property(readonly) CMVideoDimensions videoDimensions;
@property(nonatomic, readonly) AVCaptureVideoOrientation videoOrientation;

@end

@protocol CapturePipelineDelegate <NSObject>
@required

- (void)capturePipeline:(CapturePipeline *)capturePipeline didStartRunningWithVideoDevice:(AVCaptureDevice *)videoDevice;
- (void)capturePipeline:(CapturePipeline *)capturePipeline didStopRunningWithError:(NSError *)error;

// Preview
- (void)capturePipeline:(CapturePipeline *)capturePipeline previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer;
- (void)capturePipelineDidRunOutOfPreviewBuffers:(CapturePipeline *)capturePipeline __attribute__((swift_name("capturePipelineDidRunOutOfPreviewBuffers(_:)")));

@end
