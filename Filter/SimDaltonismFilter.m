
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
//  ==========================================================================
//	ADDITIONAL CONDITIONS
//	The color blindness simulation algorithm in this file is a derivative work
//	of the color_blind_sim javascript function from the Color Laboratory.
//	The original copyright and licensing terms below apply *in addition* to
//	the Apache License 2.0.
//	Original: http://colorlab.wickline.org/colorblind/colorlab/engine.js
//  --------------------------------------------------------------------------
//	The color_blind_sims() JavaScript function in the is
//	copyright (c) 2000-2001 by Matthew Wickline and the
//	Human-Computer Interaction Resource Network ( http://hcirn.com/ ).
//
//	The color_blind_sims() function is used with the permission of
//	Matthew Wickline and HCIRN, and is freely available for non-commercial
//	use. For commercial use, please contact the
//	Human-Computer Interaction Resource Network ( http://hcirn.com/ ).
//	(This notice constitutes permission for commercial use from Matthew
//	Wickline, but you must also have permission from HCIRN.)
//	Note that use of the color laboratory hosted at aware.hwg.org does
//	not constitute commercial use of the color_blind_sims()
//	function. However, use or packaging of that function (or a derivative
//	body of code) in a for-profit piece or collection of software, or text,
//	or any other for-profit work *shall* constitute commercial use.
//
//	20151129 UPDATE [by Matthew Wickline]
//		HCIRN appears to no longer exist. This makes it impractical
//		for users to obtain permission from HCIRN in order to use
//		color_blind_sims() for commercial works. Instead:
//
//		This work is licensed under a
//		Creative Commons Attribution-ShareAlike 4.0 International License.
//		http://creativecommons.org/licenses/by-sa/4.0/

#import "SimDaltonismFilter.h"

enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXTUREPOSITON,
	ATTRIB_CP_UV,
	ATTRIB_AB_UV,
	ATTRIB_AE_UV,
	ATTRIB_ANOMALIZE,
    NUM_ATTRIBUTES
};
static GLint attribLocation[NUM_ATTRIBUTES] = {
	ATTRIB_VERTEX, ATTRIB_TEXTUREPOSITON, ATTRIB_CP_UV, ATTRIB_AB_UV, ATTRIB_AE_UV, ATTRIB_ANOMALIZE,
};
static const GLchar *attribName[NUM_ATTRIBUTES] = {
	"position", "texturecoordinate", "attr_cp_uv", "attr_ab_uv", "attr_ae_uv", "attr_anomalize"
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

@implementation SimDaltonismFilter
{
@private
	CGRect _viewBounds;
	BOOL _mirror;
#if TARGET_OS_IPHONE
	UIInterfaceOrientation _orientation;
#endif
	GLfloat _passThroughTextureVertices[8];
	NSInteger _visionType;
}

+ (void)registerDefaults {
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
		SimVisionTypeKey: @(Deuteranopia),
	}];
}

- (NSInteger)visionType {
	if (!_fixedVisionType)
		return [[NSUserDefaults standardUserDefaults] integerForKey:SimVisionTypeKey];
	return _visionType;
}

- (void)setVisionType:(NSInteger)visionType {
	_fixedVisionType = YES;
	_visionType = visionType;
}

- (const GLchar *)vertexSource { return _STRINGIFY
(
	attribute vec4 position;
	attribute mediump vec4 texturecoordinate;
	varying mediump vec2 coordinate;
	
	attribute vec2 attr_cp_uv;
	attribute vec2 attr_ab_uv;
	attribute vec2 attr_ae_uv;
	attribute float attr_anomalize;

	varying vec2 blindness_cp_uv;
	varying float blindness_am;
	varying float blindness_ayi;
	varying float anomalize;

	void main()
	{
		gl_Position = position;
		coordinate = texturecoordinate.xy;

		blindness_cp_uv = attr_cp_uv; // confusion point
		vec2 blindness_ab_uv = attr_ab_uv; // color axis begining point (473nm)
		vec2 blindness_ae_uv = attr_ae_uv; // color axis ending point (574nm), v coord
		// slope of the color axis:
		vec2 ae_minus_ab = blindness_ae_uv - blindness_ab_uv;
		blindness_am = ae_minus_ab.y / ae_minus_ab.x;
		// "y-intercept" of axis (actually on the "v" axis at u=0)
		blindness_ayi = blindness_ab_uv.y  -  blindness_ab_uv.x * blindness_am;

		anomalize = attr_anomalize;
	}
);}

- (const GLchar *)fragmentSource { return _STRINGIFY
(
	PRECISION(mediump, float)

	varying mediump vec2 coordinate;
	uniform sampler2D videoframe;

	varying vec2 blindness_cp_uv;
	varying float blindness_am;
	varying float blindness_ayi;
	varying float anomalize;

	void main()
	{
		const vec4 white_xyz0 = vec4(0.312713, 0.329016, 0.358271, 0.);
		const float gamma_value = 2.2;
		const mat3 xyz_from_rgb_matrix = mat3(
			vec3(0.430574,	0.341550,	0.178325),
			vec3(0.222015,	0.706655,	0.071330),
			vec3(0.020183,	0.129553,	0.939180)
		);
		const mat3 rgb_from_xyz_matrix = mat3(
			vec3( 3.063218,	-1.393325,	-0.475802),
			vec3(-0.969243,	 1.875966,	 0.041555),
			vec3( 0.067871,	-0.228834,	 1.069251)
		);

		vec4 pixel = texture2D(videoframe, coordinate);
		if (anomalize <= 0.0) { // shortcut path
			// less than zero means monochromacy filter
			float m = dot(pixel.rgb, vec3(.299, .587, .114));
			gl_FragColor = mix(pixel, vec4(m,m,m,0), -anomalize);
			return;
		}

		vec3 c_rgb; vec2 c_uv; vec3 c_xyz;
		vec3 s_rgb;            vec4 s_xyz0;
		vec3 d_rgb; vec2 d_uv; vec3 d_xyz;
		
		// map RGB input into XYZ space...
		c_rgb = pow(pixel.rgb, vec3(gamma_value, gamma_value, gamma_value));
		c_xyz = c_rgb * xyz_from_rgb_matrix;
		float sum_xyz = dot(c_xyz, vec3(1., 1., 1.));
		
		// map into uvY space...
		c_uv = c_xyz.xy / sum_xyz;
		// find neutral grey at this luminosity (we keep the same Y value)
		vec4 n_xyz0 = white_xyz0 * c_xyz.yyyy / white_xyz0.yyyy;

		float clm;  float clyi;
		float adjust;  vec4 adj;

		// cl is "confusion line" between our color and the confusion point
		// clm is cl's slope, and clyi is cl's "y-intercept" (actually on the "v" axis at u=0)
		vec2 cp_uv_minus_c_uv = blindness_cp_uv - c_uv;
		clm = cp_uv_minus_c_uv.y / cp_uv_minus_c_uv.x;

		clyi = dot(c_uv, vec2(-clm, 1.));

		// find the change in the u and v dimensions (no Y change)
		d_uv.x = (blindness_ayi - clyi) / (clm - blindness_am);
		d_uv.y = (clm * d_uv.x) + clyi;
		
		// find the simulated color's XYZ coords
		float d_u_div_d_v = d_uv.x / d_uv.y;
		s_xyz0 = c_xyz.yyyy * vec4(
			d_u_div_d_v,
			1.,
			( 1. / d_uv.y - (d_u_div_d_v + 1.) ),
			0.
		);
		// and then try to plot the RGB coords
		s_rgb = s_xyz0.xyz * rgb_from_xyz_matrix;
		
		// note the RGB differences between sim color and our neutral color
		d_xyz = n_xyz0.xwz - s_xyz0.xwz;
		d_rgb = d_xyz * rgb_from_xyz_matrix;
		
		// find out how much to shift sim color toward neutral to fit in RGB space:
		adj.rgb = ( 1. - s_rgb ) / d_rgb;
		adj.a = 0.;

		adj = sign(1.-adj) * adj;
		adjust = max(max(0., adj.r), max(adj.g, adj.b));

		// now shift *all* three proportional to the greatest shift...
		s_rgb = s_rgb + ( adjust * d_rgb );

		// anomalize
		s_rgb = mix(c_rgb, s_rgb, anomalize);

		pixel.rgb = pow(s_rgb, vec3(1./gamma_value, 1./gamma_value, 1./gamma_value));
		gl_FragColor = pixel;
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
#if TARGET_OS_IPHONE
	_mirror = view.mirrorTransform;
#endif
}

- (void)applyParametersForTextureOfWidth:(size_t)textureWidth height:(size_t)textureHeight {
	NSInteger visionType = self.visionType;
	switch (visionType) {
		case NormalVision:
			break;
		case Deuteranopia:
		case Deuteranomaly:
			glVertexAttrib2f( ATTRIB_CP_UV, 1.14, -0.14 );
			glVertexAttrib2f( ATTRIB_AB_UV, 0.102776, 0.102864 );
			glVertexAttrib2f( ATTRIB_AE_UV, 0.505845, 0.493211 );
			break;
		case Protanopia:
		case Protanomaly:
			glVertexAttrib2f( ATTRIB_CP_UV, 0.735, 0.265 );
			glVertexAttrib2f( ATTRIB_AB_UV, 0.115807, 0.073581 );
			glVertexAttrib2f( ATTRIB_AE_UV, 0.471899, 0.527051 );
			break;
		case Tritanopia:
		case Tritanomaly:
			glVertexAttrib2f( ATTRIB_CP_UV, 0.171, -0.003 );
			glVertexAttrib2f( ATTRIB_AB_UV, 0.045391, 0.294976 );
			glVertexAttrib2f( ATTRIB_AE_UV, 0.665764, 0.334011 );
			break;
		case Monochromacy:
		case PartialMonochromacy:
			break;
	}
	switch (visionType) {
		case NormalVision:
			glVertexAttrib1f( ATTRIB_ANOMALIZE, 0.0 );
			break;
		case Deuteranopia:
		case Protanopia:
		case Tritanopia:
			glVertexAttrib1f( ATTRIB_ANOMALIZE, 1.0 );
			break;
		case Deuteranomaly:
		case Protanomaly:
		case Tritanomaly:
			glVertexAttrib1f( ATTRIB_ANOMALIZE, 0.66 );
			break;
		case Monochromacy:
			glVertexAttrib1f( ATTRIB_ANOMALIZE, -1.0 );
			break;
		case PartialMonochromacy:
			glVertexAttrib1f( ATTRIB_ANOMALIZE, -0.66 );
			break;
	}

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


NSString *SimVisionTypeName(NSInteger visionType) {
	switch (visionType) {
		case NormalVision:
			return NSLocalizedStringFromTable(@"Normal Vision", @"SimDaltonismFilter", @"");
		case Deuteranopia:
			return NSLocalizedStringFromTable(@"Deuteranopia", @"SimDaltonismFilter", @"");
		case Deuteranomaly:
			return NSLocalizedStringFromTable(@"Deuteranomaly", @"SimDaltonismFilter", @"");
		case Protanopia:
			return NSLocalizedStringFromTable(@"Protanopia", @"SimDaltonismFilter", @"");
		case Protanomaly:
			return NSLocalizedStringFromTable(@"Protanomaly", @"SimDaltonismFilter", @"");
		case Tritanopia:
			return NSLocalizedStringFromTable(@"Tritanopia", @"SimDaltonismFilter", @"");
		case Tritanomaly:
			return NSLocalizedStringFromTable(@"Tritanomaly", @"SimDaltonismFilter", @"");
		case Monochromacy:
			return NSLocalizedStringFromTable(@"Monochromacy", @"SimDaltonismFilter", @"");
		case PartialMonochromacy:
			return NSLocalizedStringFromTable(@"Partial Monochromacy", @"SimDaltonismFilter", @"");
		default:
			return @"?";
	}
}

NSString *SimVisionTypeDesc(NSInteger visionType) {
	switch (visionType) {
		case NormalVision:
			return NSLocalizedStringFromTable(@"Trichromatic: red, green, and blue cones", @"SimDaltonismFilter", @"Description for Normal Vision");
		case Deuteranopia:
			return NSLocalizedStringFromTable(@"No red cones", @"SimDaltonismFilter", @"Description for Deuteranopia");
		case Deuteranomaly:
			return NSLocalizedStringFromTable(@"Anomalous red cones", @"SimDaltonismFilter", @"Description for Deuteranomaly");
		case Protanopia:
			return NSLocalizedStringFromTable(@"No green cone", @"SimDaltonismFilter", @"Description for Protanopia");
		case Protanomaly:
			return NSLocalizedStringFromTable(@"Anomalous green cones", @"SimDaltonismFilter", "Description for Protanomaly");
		case Tritanopia:
			return NSLocalizedStringFromTable(@"No blue cones", @"SimDaltonismFilter", "Description for Tritanopia");
		case Tritanomaly:
			return NSLocalizedStringFromTable(@"Anomalous blue cones", @"SimDaltonismFilter", "Description for Tritanomaly");
		case Monochromacy:
			return NSLocalizedStringFromTable(@"Absent or non-functionning cones", @"SimDaltonismFilter", "Description for Monochromacy");
		case PartialMonochromacy:
			return NSLocalizedStringFromTable(@"Reduced sensitivity to colors", @"SimDaltonismFilter", "Description for PartialMonochromacy");
		default:
			return @"";
	}
}

