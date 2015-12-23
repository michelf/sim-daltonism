
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

#import "PaletteView.h"
#import "OpenGLPixelBufferView.h"

const size_t numColumns = 8;
const size_t numRows = 8;
const CGFloat colors[numColumns*3] = {
	0.0, 0.0, 0.9,
	0.8, 0.0, 1.0,
	1.0, 0.0, 0.0,
	1.0, 0.63, 0.0,
	1.0, 0.94, 0.0,
	0.7, 1.0, 0.0,
	0.0, 1.0, 0.0,
	0.0, 0.8, 1.0,
};
const CGFloat whiteBlackEffect[numRows*2] = {
	0.3, 1.0,
	0.5, 1.0,
	0.7, 1.0,
	0.9, 1.0,
	1.0, 1.0, // middle
	1.0, 0.63,
	1.0, 0.4,
	1.0, 0.2,
};
const CGFloat margin = 2;

@implementation PaletteView
{
@private
	UIView *_colorViews[numRows*numColumns];
}

- (UIColor *)colorForRow:(NSInteger)row column:(NSInteger)column {
	CGFloat red = colors[column*3+0];
	CGFloat green = colors[column*3+1];
	CGFloat blue = colors[column*3+2];

	red *= whiteBlackEffect[row*2+0];
	green *= whiteBlackEffect[row*2+0];
	blue *= whiteBlackEffect[row*2+0];

	red = 1.0 - ((1.0 - red) * whiteBlackEffect[row*2+1]);
	green = 1.0 - ((1.0 - green) * whiteBlackEffect[row*2+1]);
	blue = 1.0 - ((1.0 - blue) * whiteBlackEffect[row*2+1]);

	return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}

- (void)_recolorViews {
	for (size_t column = 0; column < numColumns; ++column) {
		for (size_t row = 0; row < numRows; ++row) {
			size_t viewIndex = row + column*numRows;
			_colorViews[viewIndex].backgroundColor = [self colorForRow:row column:column];
			[UIView transitionFromView:_colorViews[viewIndex] toView:_colorViews[viewIndex] duration:0.1 options:UIViewAnimationOptionTransitionFlipFromTop|UIViewAnimationOptionShowHideTransitionViews completion:nil];
		}
	}
}

- (void)layoutSubviews {
	CGRect bounds = self.bounds;
	CGRect colorRect = CGRectMake(
		margin,
		margin,
		MAX(margin, floor((bounds.size.width - margin) / numColumns) - 2*margin),
		MAX(margin, floor((bounds.size.height - margin) / numRows) - 2*margin));
	colorRect.origin.x = round((bounds.size.width - (colorRect.size.width + margin) * numColumns) / 2);

	for (size_t column = 0; column < numColumns; ++column) {
		CGRect localRect = colorRect;
		for (size_t row = 0; row < numRows; ++row) {
			size_t viewIndex = row + column*numRows;
			if (_colorViews[viewIndex] == nil)
			{
				_colorViews[viewIndex] = [UIView new];
				_colorViews[viewIndex].layer.cornerRadius = 6;
				[self addSubview:_colorViews[viewIndex]];
			}

			_colorViews[viewIndex].frame = localRect;
			_colorViews[viewIndex].backgroundColor = [self colorForRow:row column:column];

			localRect.origin.y += colorRect.size.height + margin;
		}
		colorRect.origin.x += colorRect.size.width + margin;
	}

	[self performSelector:@selector(_recolorViews) withObject:nil afterDelay:1.0];
}

@end
