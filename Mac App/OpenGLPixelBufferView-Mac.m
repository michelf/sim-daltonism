
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

#import "OpenGLPixelBufferView-Mac.h"
#import "OpenGLShaderFilter.h"
#import "ShaderUtilities.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/gl3.h>
#import <CoreVideo/CoreVideo.h>

@interface OpenGLPixelBufferView ()
{
	CVOpenGLTextureCacheRef _textureCache;
	GLint _width;
	GLint _height;
	GLuint _frameBufferHandle;
	GLuint _colorBufferHandle;
    GLuint _program;
	GLint _frame;
}
@end

@implementation OpenGLPixelBufferView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame pixelFormat:[self.class defaultPixelFormat]];
    if ( self )
	{
    }
    return self;
}

- (void)prepareOpenGL
{
	id<OpenGLShaderFilter> filter = self.filter;
    glueCreateProgram(filter.vertexSource, filter.fragmentSource,
                      filter.attributeCount, filter.attributeNames, filter.attributeLocations,
                      0, 0, 0,
                      &_program );

    if ( ! _program ) {
		NSLog( @"Error creating the program" );
	}
	
	_frame = glueGetUniformLocation( _program, "videoframe" );
}

- (void)reset
{
	NSOpenGLContext *oldContext = [NSOpenGLContext currentContext];
	if ( oldContext != self.openGLContext ) {
		[self.openGLContext makeCurrentContext];
	}
    if ( _frameBufferHandle ) {
        glDeleteFramebuffers( 1, &_frameBufferHandle );
        _frameBufferHandle = 0;
    }
    if ( _colorBufferHandle ) {
        glDeleteRenderbuffers( 1, &_colorBufferHandle );
        _colorBufferHandle = 0;
    }
    if ( _program ) {
        glDeleteProgram( _program );
        _program = 0;
    }
    if ( _textureCache ) {
        CFRelease( _textureCache );
        _textureCache = 0;
    }
	if ( oldContext != self.openGLContext ) {
		[oldContext makeCurrentContext];
	}
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidMoveNotification object:self.window];
	[super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reshape) name:NSWindowDidChangeBackingPropertiesNotification object:self.window];
	[self reshape];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self reset];
}

- (void)reshape
{
	CGLLockContext(self.openGLContext.CGLContextObj);
	[self.openGLContext makeCurrentContext];

	[self.filter prepareForView:self];

    NSRect bounds = [self bounds];
	CGFloat scale = self.window.backingScaleFactor;

    GLsizei w = NSWidth(bounds) * scale;
    GLsizei h = NSHeight(bounds) * scale;
	
    glViewport(0, 0, w, h); // Map OpenGL projection plane to NSWindow

	CGLUnlockContext(self.openGLContext.CGLContextObj);
}

- (void)displayImage:(CGImageRef)image scale:(CGFloat)scale
{
	CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
	if (!data)
		return;
	size_t imageWidth = CGImageGetWidth(image);
	size_t imageHeight = CGImageGetHeight(image);
	size_t imageBytesPerRow = CGImageGetBytesPerRow(image);
	size_t imageBitsPerPixel = CGImageGetBitsPerPixel(image);
	void *imageDataPtr = (void *)CFDataGetBytePtr(data);

	NSOpenGLContext *context = self.openGLContext;
	CGLLockContext(context.CGLContextObj);
	[context makeCurrentContext];

	glDisable( GL_DEPTH_TEST );
	
	glUseProgram( _program );
    glActiveTexture( GL_TEXTURE0 );
	glBindTexture(GL_TEXTURE_2D, 13);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glPixelStorei(GL_UNPACK_ROW_LENGTH, (int)imageBytesPerRow/(imageBitsPerPixel/8));
	switch (imageBitsPerPixel) {
		case 16:
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, (int)imageWidth, (int)imageHeight, 0, GL_BGRA, GL_UNSIGNED_SHORT_1_5_5_5_REV, imageDataPtr);
			break;
		case 32:
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, (int)imageWidth, (int)imageHeight, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, imageDataPtr);
			break;
		default:
			CFRelease(data);
			return; // cannot deduce pixel format
	}

	glUniform1i( _frame, 0 );

    // Set texture parameters
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );

	[self.filter applyParametersForTextureOfWidth:imageWidth height:imageHeight];

	glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );

	CFRelease(data);

    [context flushBuffer];
	CGLUnlockContext(context.CGLContextObj);
}

- (void)flushPixelBufferCache
{
	if ( _textureCache ) {
		CVOpenGLTextureCacheFlush(_textureCache, 0);
	}
}

@end
