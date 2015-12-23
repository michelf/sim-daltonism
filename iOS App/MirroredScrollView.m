
//	Copyright 2015 Michel Fortin
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

#import "MirroredScrollView.h"

@implementation MirroredScrollView

- (void)didMoveToWindow {
	if (self.mirrorView == nil) {
		[self _setupMirrorView];
	}
}

- (void)_setupMirrorView {
	OpenGLPixelBufferView *mirrorView = [[OpenGLPixelBufferView alloc] initWithFrame:self.frame];
	mirrorView.userInteractionEnabled = NO;
	mirrorView.opaque = YES;
	mirrorView.translatesAutoresizingMaskIntoConstraints = NO;
	mirrorView.transform = CGAffineTransformMakeScale(-1, 1);
	self.mirrorView = mirrorView;

	[self.superview insertSubview:mirrorView aboveSubview:self];
	[NSLayoutConstraint deactivateConstraints:mirrorView.constraints];
	[NSLayoutConstraint activateConstraints:@[
		[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:mirrorView attribute:NSLayoutAttributeTop multiplier:1 constant:0],
		[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:mirrorView attribute:NSLayoutAttributeLeft multiplier:1 constant:0],
		[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:mirrorView attribute:NSLayoutAttributeHeight multiplier:1 constant:0],
		[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:mirrorView attribute:NSLayoutAttributeWidth multiplier:1 constant:0],
	]];

	[mirrorView displayViewContent:self];
}

- (void)updateDisplay {
	[self.mirrorView displayViewContent:self];
}

- (void)setContentOffset:(CGPoint)contentOffset {
	[super setContentOffset:contentOffset];
	[self updateDisplay];
}

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	[self.mirrorView displayViewContent:self];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	[self.mirrorView performSelector:@selector(displayViewContent:) withObject:self afterDelay:0.0];
}

@end
