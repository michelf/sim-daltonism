//    Copyright 2005-2017 Michel Fortin
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.


#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

extern "C" {

	namespace coreimage {

		// X: normalized x for luminance
		// Y: normalized y for luminance
		// S: saturation (HSL formula)
		// L: lightness (HSL formula)
		float4 rgb2rgsl(float3 c)
		{
			float cmax = max(max(c.r, c.g), c.b);
			float cmin = min(min(c.r, c.g), c.b);
			float delta = cmax - cmin;
			float zeroGate = step(0., delta);
			float lx2 = (cmax + cmin);
			float s = delta / (1. - abs(lx2 - 1.));
			return zeroGate * float4((c.rg - cmin) / delta, s, lx2 * 0.5);
		}
		float lightness(float3 c)
		{
			float cmax = max(max(c.r, c.g), c.b);
			float cmin = min(min(c.r, c.g), c.b);
			float lx2 = (cmax + cmin);
			return lx2 * 0.5;
		}
		float hsvsaturation(float3 c)
		{
			float cmax = max(max(c.r, c.g), c.b);
			float cmin = min(min(c.r, c.g), c.b);
			float C = (cmax - cmin);
			float V = cmax;
			return C / V;
		}

		float mixture(float3 color, float redGreenMix, float mixPower, float saturationPower, float saturationThreshold)
		{
			float redGreenFactor = dot(normalize(color.rg), float2(1.0, -1.0));
			float blueFactor = clamp(dot(normalize(color), float3(1., 0., -.2)), 0., 1.);
			float4 rgsl = rgb2rgsl(color.rgb);
			float halfIntensity = sqrt(rgsl.w) * sqrt(1.-rgsl.w) * 2.;

			float mixture = clamp(redGreenMix * redGreenFactor, 0., 1.) * blueFactor * clamp(halfIntensity * 1.5, 0., 1.);
			return pow(mixture, mixPower);
		}
		// x: primary (red/green)
		// y: opposing secondary (green/red)
		// z: opposing tertiary (blue/blue)
		float mixture2(float3 values, float xyMix, float power, float zThreshold) {
			float xyFactor = clamp(dot(normalize(values.xy), float2(1., -1.)), 0., 1.);
			float zFactor = clamp(zThreshold - 2. * normalize(values).z, 0., 1.);
			float light = lightness(values) * clamp(5. * (-0.02 + hsvsaturation(values)), 0., 1.);
			float mixture = clamp(xyMix, 0., 1.) * xyFactor * zFactor * clamp(4. * pow(light, 2.), 0.0, 1.0);
			return pow(clamp(mixture, 0., 1.), power);
		}
		float makePrimary(float mixValue) {
			float factor = 1.3;
			return clamp(mixValue * factor - (factor - 1.), 0.0, 1.0);
		}

		float redMix(float3 color, float showRed) {
			return mixture(color, 1. * showRed, 1.8, .75, .0);
		}
		float redPrimaryMix(float3 color, float showRed) {
			return makePrimary( mixture(color, 1. * showRed, 1.0, .75, .0));
		}

		float greenMix(float3 color, float showGreen) {
 			color = sqrt(max(color, 0.));
			return mixture2(color.grb, 1. * showGreen, 0.4, 2.0);
		}
		float greenPrimaryMix(float3 color, float showGreen) {
			color = sqrt(max(color, 0.));
			return clamp(mixture2(color.grb, 1. * showGreen, 0.4, 1.3) * 1.4, 0., 1.);
		}

		float blueMix(float3 color, float showBlue) {
			color = sqrt(max(color, 0.));
			return mixture2(.5*(color.brg + color.bgr), 1. * showBlue, 0.7, 2.0);
		}
		float bluePrimaryMix(float3 color, float showBlue) {
			color = sqrt(max(color, 0.));
			return clamp(mixture2(.5*(color.brg + color.bgr), 1. * showBlue, 0.7, 3.3) * 1.4, 0., 1.);
		}

		float modDown(float a, float b) {
			return ((a/b) - floor((a/b))) * b;
		}

		float4 stripes_kernel(float4 color, float showRed, float showGreen, float showBlue, float patternscale, destination dest) {
			float stepBound = patternscale * 8.0;
			float blueStepBound = patternscale * 6.0;

			float2 coord = dest.coord();
			float stepRed = modDown(showRed * (coord.y + coord.x), stepBound);
			float stepNonGreen = modDown(showGreen * (coord.y + coord.x), stepBound);
			float stepGreen = modDown(showGreen * (coord.y - coord.x), stepBound);
			float stepBlue = modDown(showBlue * (1. + coord.y), blueStepBound);

			// Red
			if (stepRed < patternscale)
			{
				// Shallow red
				float3 stripeColor = float3(1., 1., 1.);
				color.rgb = mix(color.rgb, stripeColor, redPrimaryMix(color.rgb, showRed));
			}
			else if (stepRed >= patternscale * 6.0 && stepRed < stepBound)
			{
				// Deep red
				float3 stripeColor = float3(0., 0., 0.);
				color.rgb = mix(color.rgb, stripeColor, redMix(color.rgb, showRed));
			}
			// Mac has two stripe sizes, can't use red pattern check for the dashes.
			if (stepNonGreen < patternscale) {}
			else if (stepNonGreen >= patternscale * 6.0 && stepNonGreen < stepBound) {}
			else // now insert green stripe checks
			// Green
			if (stepGreen < patternscale)
			{
				// Shallow green
				float3 stripeColor = float3(1., 1., 1.);
				color.rgb = mix(color.rgb, stripeColor, greenPrimaryMix(color.rgb, showGreen));
			}
			else if (stepGreen >= patternscale * 6.0 && stepGreen < stepBound)
			{
				// Deep green
				float3 stripeColor = float3(0., 0., 0.);
				color.rgb = mix(color.rgb, stripeColor, greenMix(color.rgb, showGreen));
			}
			// Blue
			if (stepBlue < patternscale)
			{
				// Shallow blue
				float3 stripeColor = float3(1., 1., 1.);
				color.rgb = mix(color.rgb, stripeColor, bluePrimaryMix(color.rgb, showBlue));
			}
			else if (stepBlue >= patternscale * 5.0 && stepBlue < blueStepBound)
			{
				// Deep blue
				float3 stripeColor = float3(0., 0., 0.);
				color.rgb = mix(color.rgb, stripeColor, blueMix(color.rgb, showBlue));
			}
			return color;
		}

		float4 addVibrancy_kernel(float4 color) {
			const float colorBoost = 1.5;
			const float boostGamma = 2.2 - 0.3;
			color.rgb = clamp(color.rgb, 0., 1000);
			color.rgb = pow(color.rgb, 1/boostGamma);
			float boostLightness = lightness(color.rgb);
			color.rgb = (colorBoost*color.rgb - normalize(color.gbr * color.brg + .001) * boostLightness);
			color.rgb = pow(color.rgb, boostGamma);
			return clamp(color, 0., 1.);
		}

		// All components are in the range [0…1], including hue.
		float3 rgb2hsv(float3 c)
		{
			float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
			float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

			float d = q.x - min(q.w, q.y);
			float e = 1.0e-10;
			return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
		}


		// All components are in the range [0…1], including hue.
		float3 hsv2rgb(float3 c)
		{
			float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
			float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
			return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
		}

		float4 invertHue_kernel(float4 color) {
			float3 hsvColor = rgb2hsv(color.rgb);
			hsvColor.x = fract(hsvColor.x + 0.5);
			color.rgb = hsv2rgb(hsvColor);
			return color;
		}

	}
}
