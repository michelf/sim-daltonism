
//	Copyright 2005-2016 Michel Fortin
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

#import "OpenGLShaderFilter.h"

@interface SimDaltonismFilter : NSObject <OpenGLShaderFilter>

+ (void)registerDefaults;

// Fixed vision type will not change with user defaults
@property (nonatomic) BOOL fixedVisionType;
@property (nonatomic) NSInteger visionType;

@end

NS_ENUM(NSInteger) {
	NormalVision,
	Deuteranopia,
	Deuteranomaly,
	Protanopia,
	Protanomaly,
	Tritanopia,
	Tritanomaly,
	Monochromacy,
	PartialMonochromacy,
	MAX_VISION_TYPE
};

#define SimVisionTypeKey @"SimVisionType"

NSString *SimVisionTypeName(NSInteger visionType);
NSString *SimVisionTypeDesc(NSInteger visionType);