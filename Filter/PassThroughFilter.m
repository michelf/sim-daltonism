
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

#import "PassThroughFilter.h"

enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXTUREPOSITON,
    NUM_ATTRIBUTES
};
static GLint attribLocation[NUM_ATTRIBUTES] = {
	ATTRIB_VERTEX, ATTRIB_TEXTUREPOSITON
};
static const GLchar *attribName[NUM_ATTRIBUTES] = {
	"position", "texturecoordinate"
};

static void swapGLfloat(GLfloat * a, GLfloat * b) {
	GLfloat tmp = *a;
	*a = *b;
	*b = tmp;
}

// Macros to handle the differences between OpenGLES and OpenGL
#if TARGET_OS_IPHONE
#	define  PRECISION(P, TYPE)  precision P TYPE;
#elif TARGET_OS_MAC
#	define  mediump
#	define  highp
#	define  PRECISION(P, TYPE)
#endif

@implementation PassThroughFilter
{
@private
	CGRect _viewBounds;
	BOOL _mirror;
	GLfloat _passThroughTextureVertices[8];
}

- (const GLchar *)vertexSource { return _STRINGIFY
(
	attribute vec4 position;
	attribute mediump vec4 texturecoordinate;
	varying mediump vec2 coordinate;

	void main()
	{
		gl_Position = position;
		coordinate = texturecoordinate.xy;
	}
);}

- (const GLchar *)fragmentSource { return _STRINGIFY
(
	varying highp vec2 coordinate;
	uniform sampler2D videoframe;

	void main()
	{
		gl_FragColor = texture2D(videoframe, coordinate);
	}
);}

- (GLsizei)attributeCount {
	return NUM_ATTRIBUTES;
}
- (GLint *)attributeLocations {
	return attribLocation;
}
- (const GLchar **)attributeNames {
    return attribName;
}

- (void)prepareForView:(OpenGLPixelBufferView *)view {
	_viewBounds = view.bounds;
	_mirror = view.mirrorTransform;
}

- (void)applyParametersForTextureOfWidth:(size_t)textureWidth height:(size_t)textureHeight {
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f, // bottom left
        1.0f, -1.0f, // bottom right
        -1.0f,  1.0f, // top left
        1.0f,  1.0f, // top right
    };
	
	glVertexAttribPointer( ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices );
	glEnableVertexAttribArray( ATTRIB_VERTEX );

	// Preserve aspect ratio; fill layer bounds
    CGSize textureSamplingSize;
    CGSize cropScaleAmount = CGSizeMake( _viewBounds.size.width / (float)textureWidth, _viewBounds.size.height / (float)textureHeight );
    if ( cropScaleAmount.height > cropScaleAmount.width ) {
        textureSamplingSize.width = _viewBounds.size.width / ( textureWidth * cropScaleAmount.height );
        textureSamplingSize.height = 1.0;
    }
    else {
        textureSamplingSize.width = 1.0;
        textureSamplingSize.height = _viewBounds.size.height / ( textureHeight * cropScaleAmount.width );
    }

	// Perform a vertical flip by swapping the top left and the bottom left coordinate.
	// CVPixelBuffers have a top left origin and OpenGL has a bottom left origin.
    _passThroughTextureVertices[0] = ( 1.0 - textureSamplingSize.width ) / 2.0;
	_passThroughTextureVertices[1] = ( 1.0 + textureSamplingSize.height ) / 2.0; // top left
    _passThroughTextureVertices[2] = ( 1.0 + textureSamplingSize.width ) / 2.0;
	_passThroughTextureVertices[3] = ( 1.0 + textureSamplingSize.height ) / 2.0; // top right
    _passThroughTextureVertices[4] = ( 1.0 - textureSamplingSize.width ) / 2.0;
	_passThroughTextureVertices[5] = ( 1.0 - textureSamplingSize.height ) / 2.0; // bottom left
    _passThroughTextureVertices[6] = ( 1.0 + textureSamplingSize.width ) / 2.0;
	_passThroughTextureVertices[7] = ( 1.0 - textureSamplingSize.height ) / 2.0; // bottom right

	if (_mirror) {
		swapGLfloat(&_passThroughTextureVertices[0], &_passThroughTextureVertices[2]);
		swapGLfloat(&_passThroughTextureVertices[4], &_passThroughTextureVertices[6]);
	}

	glVertexAttribPointer( ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, _passThroughTextureVertices );
	glEnableVertexAttribArray( ATTRIB_TEXTUREPOSITON );
}

@end
