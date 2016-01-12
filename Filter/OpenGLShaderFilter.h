
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

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#	import <OpenGLES/EAGL.h>
#	import <OpenGLES/gltypes.h>
#	import <OpenGLES/ES2/gl.h>
#	import "OpenGLPixelBufferView.h"
#elif TARGET_OS_MAC
#	import <OpenGL/OpenGL.h>
#	import <OpenGL/gl.h>
#	import <OpenGL/gl3.h>
#	import "OpenGLPixelBufferView-Mac.h"
#endif

#if !defined(_STRINGIFY)
#define __STRINGIFY( _x )   # _x
#define _STRINGIFY( _x )   __STRINGIFY( _x )
#endif

@protocol OpenGLShaderFilter <NSObject>

@property (nonatomic, readonly) const GLchar *vertexSource;
@property (nonatomic, readonly) const GLchar *fragmentSource;

@property (nonatomic, readonly) GLsizei attributeCount;
@property (nonatomic, readonly) GLint *attributeLocations;
@property (nonatomic, readonly) const GLchar **attributeNames;

- (void)prepareForView:(OpenGLPixelBufferView *)view;

// !!! called from a background thread !!!
- (void)applyParametersForTextureOfWidth:(size_t)textureWidth height:(size_t)textureHeight;

@end
