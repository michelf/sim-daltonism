
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

#import "OpenGLPixelBufferView.h"
#import <OpenGLES/EAGL.h>
#import <QuartzCore/CAEAGLLayer.h>
#import "ShaderUtilities.h"
#import "OpenGLShaderFilter.h"

@interface OpenGLPixelBufferView ()
{
	EAGLContext *_oglContext;
	CVOpenGLESTextureCacheRef _textureCache;
	GLint _width;
	GLint _height;
	GLuint _frameBufferHandle;
	GLuint _colorBufferHandle;
    GLuint _program;
	GLint _frame;
}
@end

@implementation OpenGLPixelBufferView

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if ( self )
	{
		// On iOS8 and later we use the native scale of the screen as our content scale factor.
		// This allows us to render to the exact pixel resolution of the screen which avoids additional scaling and GPU rendering work.
		// For example the iPhone 6 Plus appears to UIKit as a 736 x 414 pt screen with a 3x scale factor (2208 x 1242 virtual pixels).
		// But the native pixel dimensions are actually 1920 x 1080.
		// Since we are streaming 1080p buffers from the camera we can render to the iPhone 6 Plus screen at 1:1 with no additional scaling if we set everything up correctly.
		// Using the native scale of the screen also allows us to render at full quality when using the display zoom feature on iPhone 6/6 Plus.
		
		// Only try to compile this code if we are using the 8.0 or later SDK.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
		if ( [UIScreen instancesRespondToSelector:@selector(nativeScale)] )
		{
			self.contentScaleFactor = [UIScreen mainScreen].nativeScale;
		}
		else
#endif
		{
			self.contentScaleFactor = [UIScreen mainScreen].scale;
		}
		
        // Initialize OpenGL ES 2
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking : @(YES),
										  kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8 };

		_oglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		if ( ! _oglContext ) {
			NSLog( @"Problem with OpenGL context." );
			return nil;
		}

		Class c = NSClassFromString([NSBundle mainBundle].infoDictionary[@"FilterClass"]);
		assert(c);
		self.filter = [c new];
    }
    return self;
}

- (void)didMoveToWindow {
	[super didMoveToWindow];
	[_filter prepareForView:self];
}

- (void)setBounds:(CGRect)bounds {
	[super setBounds:bounds];
	[_filter prepareForView:self];
}

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	[_filter prepareForView:self];
}

- (void)setMirrorTransform:(BOOL)mirrorTransform
{
	if (_mirrorTransform == mirrorTransform) return;
	_mirrorTransform = mirrorTransform;
	[_filter prepareForView:self];
}

- (void)setFilter:(id<OpenGLShaderFilter>)filter {
	assert(filter);
	_filter = filter;
	[_filter prepareForView:self];
}

- (BOOL)initializeBuffers
{
	BOOL success = YES;
	
	glDisable( GL_DEPTH_TEST );
    
    glGenFramebuffers( 1, &_frameBufferHandle );
    glBindFramebuffer( GL_FRAMEBUFFER, _frameBufferHandle );
    
    glGenRenderbuffers( 1, &_colorBufferHandle );
    glBindRenderbuffer( GL_RENDERBUFFER, _colorBufferHandle );
    
    [_oglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
	glGetRenderbufferParameteriv( GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width );
    glGetRenderbufferParameteriv( GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height );
    
    glFramebufferRenderbuffer( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBufferHandle );
	if ( glCheckFramebufferStatus( GL_FRAMEBUFFER ) != GL_FRAMEBUFFER_COMPLETE ) {
        NSLog( @"Failure with framebuffer generation" );
		success = NO;
		goto bail;
	}
    
    //  Create a new CVOpenGLESTexture cache
    CVReturn err = CVOpenGLESTextureCacheCreate( kCFAllocatorDefault, NULL, _oglContext, NULL, &_textureCache );
    if ( err ) {
        NSLog( @"Error at CVOpenGLESTextureCacheCreate %d", err );
        success = NO;
		goto bail;
    }

    glueCreateProgram(_filter.vertexSource, _filter.fragmentSource,
                      _filter.attributeCount, _filter.attributeNames, _filter.attributeLocations,
                      0, 0, 0,
                      &_program );

    if ( ! _program ) {
		NSLog( @"Error creating the program" );
        success = NO;
		goto bail;
	}
	
	_frame = glueGetUniformLocation( _program, "videoframe" );
	
bail:
	if ( ! success ) {
		[self reset];
	}
    return success;
}

- (void)reset
{
	EAGLContext *oldContext = [EAGLContext currentContext];
	if ( oldContext != _oglContext ) {
		if ( ! [EAGLContext setCurrentContext:_oglContext] ) {
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Problem with OpenGL context" userInfo:nil];
			return;
		}
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
	if ( oldContext != _oglContext ) {
		[EAGLContext setCurrentContext:oldContext];
	}
}

- (void)dealloc
{
	[self reset];
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
	if ( pixelBuffer == NULL ) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"NULL pixel buffer" userInfo:nil];
		return;
	}

	EAGLContext *oldContext = [EAGLContext currentContext];
	if ( oldContext != _oglContext ) {
		if ( ! [EAGLContext setCurrentContext:_oglContext] ) {
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Problem with OpenGL context" userInfo:nil];
			return;
		}
	}
	
	if ( _frameBufferHandle == 0 ) {
		BOOL success = [self initializeBuffers];
		if ( ! success ) {
			NSLog( @"Problem initializing OpenGL buffers." );
			return;
		}
	}
	
    // Create a CVOpenGLESTexture from a CVPixelBufferRef
	size_t frameWidth = CVPixelBufferGetWidth( pixelBuffer );
	size_t frameHeight = CVPixelBufferGetHeight( pixelBuffer );
    CVOpenGLESTextureRef texture = NULL;
    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage( kCFAllocatorDefault,
                                                                _textureCache,
                                                                pixelBuffer,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                GL_RGBA,
                                                                (GLsizei)frameWidth,
                                                                (GLsizei)frameHeight,
                                                                GL_BGRA,
                                                                GL_UNSIGNED_BYTE,
                                                                0,
                                                                &texture );
    
    
    if ( ! texture || err ) {
        NSLog( @"CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err );
        return;
    }
	
    // Set the view port to the entire view
	glBindFramebuffer( GL_FRAMEBUFFER, _frameBufferHandle );
    glViewport( 0, 0, _width, _height );
	
	glUseProgram( _program );
    glActiveTexture( GL_TEXTURE0 );
	glBindTexture( CVOpenGLESTextureGetTarget( texture ), CVOpenGLESTextureGetName( texture ) );
	glUniform1i( _frame, 0 );
    
    // Set texture parameters
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );

	[_filter applyParametersForTextureOfWidth:frameWidth height:frameHeight];
	
	glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );
	
	glBindRenderbuffer( GL_RENDERBUFFER, _colorBufferHandle );
    [_oglContext presentRenderbuffer:GL_RENDERBUFFER];
	
    glBindTexture( CVOpenGLESTextureGetTarget( texture ), 0 );
	glBindTexture( GL_TEXTURE_2D, 0 );
    CFRelease( texture );
	
	if ( oldContext != _oglContext ) {
		[EAGLContext setCurrentContext:oldContext];
	}
}

- (void)displayImage:(UIImage *)image
{
	//Image size
	size_t originalWidth = CGImageGetWidth(image.CGImage);
	size_t originalHeight = CGImageGetHeight(image.CGImage);
	size_t bitsPerComponent = 8;

	// resize if image is too big for fitting into OpenGL context
	size_t width = originalWidth;
	size_t height = originalHeight;
	size_t maxSize = 3000;
	if (width > maxSize) {
		height *= (CGFloat)maxSize / width;
		width = maxSize;
	}
	if (height > maxSize) {
		width *= (CGFloat)maxSize / height;
		height = maxSize;
	}

	//Create context
	size_t bytesPerRow = 4 * width;
	void *imageData = malloc(height * bytesPerRow);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(imageData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(colorSpace);

	//Prepare image
	CGContextClearRect(context, CGRectMake(0, 0, width, height));
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), image.CGImage);

	//Release
	CGContextRelease(context);
	//free(imageData);

	EAGLContext *oldContext = [EAGLContext currentContext];
	if ( oldContext != _oglContext ) {
		if ( ! [EAGLContext setCurrentContext:_oglContext] ) {
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Problem with OpenGL context" userInfo:nil];
			return;
		}
	}
	
	if ( _frameBufferHandle == 0 ) {
		BOOL success = [self initializeBuffers];
		if ( ! success ) {
			NSLog( @"Problem initializing OpenGL buffers." );
			free(imageData);
			return;
		}
	}

	size_t imageWidth = width;
	size_t imageHeight = height;
	
	glDisable( GL_DEPTH_TEST );
	
    // Set the view port to the entire view
	glBindFramebuffer( GL_FRAMEBUFFER, _frameBufferHandle );
    glViewport( 0, 0, _width, _height );
	
	glUseProgram( _program );
    glActiveTexture( GL_TEXTURE0 );
	glBindTexture(GL_TEXTURE_2D, 13);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)imageWidth, (int)imageHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);

	glUniform1i( _frame, 0 );

    // Set texture parameters
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );

	[_filter applyParametersForTextureOfWidth:imageWidth height:imageHeight];
	
	glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );

	glBindRenderbuffer( GL_RENDERBUFFER, _colorBufferHandle );
    [_oglContext presentRenderbuffer:GL_RENDERBUFFER];

	free(imageData);

	if ( oldContext != _oglContext ) {
		[EAGLContext setCurrentContext:oldContext];
	}
}


- (void)displayViewContent:(UIView *)view
{
	//Image size
	CALayer *layer = view.layer;
	CGRect viewFrame = layer.bounds;
	//CGRect viewBounds = view.layer.bounds;
	CGFloat factor = view.window.screen.scale;
	size_t width = viewFrame.size.width * factor;
	size_t height = viewFrame.size.height * factor;
	size_t bitsPerComponent = 8;
	size_t bytesPerRow = 4 * width;

	//Create context
	void *imageData = malloc(height * bytesPerRow);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(imageData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(colorSpace);

	if (context == nil)
		return;

	//Prepare image
	CGContextTranslateCTM(context, 0, height);
	CGContextScaleCTM(context, factor, -factor);
	CGContextTranslateCTM(context, -layer.bounds.origin.x, -layer.bounds.origin.y);
	CGContextClearRect(context, CGRectMake(0, 0, width, height));
	[layer renderInContext:context];

	//Release
	CGContextRelease(context);

	EAGLContext *oldContext = [EAGLContext currentContext];
	if ( oldContext != _oglContext ) {
		if ( ! [EAGLContext setCurrentContext:_oglContext] ) {
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Problem with OpenGL context" userInfo:nil];
			return;
		}
	}
	
	if ( _frameBufferHandle == 0 ) {
		BOOL success = [self initializeBuffers];
		if ( ! success ) {
			NSLog( @"Problem initializing OpenGL buffers." );
			free(imageData);
			return;
		}
	}

	size_t imageWidth = width;
	size_t imageHeight = height;
	
	glDisable( GL_DEPTH_TEST );
	
    // Set the view port to the entire view
	glBindFramebuffer( GL_FRAMEBUFFER, _frameBufferHandle );
    glViewport( 0, 0, _width, _height );
	
	glUseProgram( _program );
    glActiveTexture( GL_TEXTURE0 );
	glBindTexture(GL_TEXTURE_2D, 13);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)imageWidth, (int)imageHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);

	glUniform1i( _frame, 0 );

    // Set texture parameters
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );

	[_filter applyParametersForTextureOfWidth:imageWidth height:imageHeight];
	
	glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );

	glBindRenderbuffer( GL_RENDERBUFFER, _colorBufferHandle );
    [_oglContext presentRenderbuffer:GL_RENDERBUFFER];

	free(imageData);

	if ( oldContext != _oglContext ) {
		[EAGLContext setCurrentContext:oldContext];
	}
}

- (void)flushPixelBufferCache
{
	if ( _textureCache ) {
		CVOpenGLESTextureCacheFlush(_textureCache, 0);
	}
}

- (UIImage *)captureCurrentImage {
	EAGLContext *oldContext = [EAGLContext currentContext];
	if ( oldContext != _oglContext ) {
		if ( ! [EAGLContext setCurrentContext:_oglContext] ) {
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Problem with OpenGL context" userInfo:nil];
			return nil;
		}
	}

	glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);

	GLint width, height;
	glGetRenderbufferParameteriv( GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width );
	glGetRenderbufferParameteriv( GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height );

	NSInteger x = 0, y = 0, width2 = width, height2 = height;
	NSInteger dataLength = width2 * height2 * 4;
	CFMutableDataRef data = CFDataCreateMutable(NULL, dataLength * sizeof(GLubyte));
	CFDataSetLength(data, dataLength * sizeof(GLubyte));

	// Read pixel data from the framebuffer
	glPixelStorei(GL_PACK_ALIGNMENT, 4);
	glReadPixels(x, y, width2, height2, GL_RGBA, GL_UNSIGNED_BYTE, CFDataGetMutableBytePtr(data));

	// Create a CGImage with the pixel data
	CGDataProviderRef ref = CGDataProviderCreateWithCFData(data);
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	CGImageRef iref = CGImageCreate(width2, height2, 8, 32, width2 * 4, colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipLast,
									ref, NULL, true, kCGRenderingIntentDefault);

	CGFloat scale = self.contentScaleFactor;
	UIImage *image = [UIImage imageWithCGImage:iref scale:scale orientation:self.captureOrientation];

	// Clean up
	CFRelease(data);
	CFRelease(ref);
	CFRelease(colorspace);
	CGImageRelease(iref);
	if ( oldContext != _oglContext ) {
		[EAGLContext setCurrentContext:oldContext];
	}

	// Redraw in correct orientation
	// (because UIImageOrientation is not handled correctly everywhere)
	UIGraphicsBeginImageContext(image.size);
	[image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height) blendMode:kCGBlendModeCopy alpha:1.0];
	image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	return image;
}

@end
