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
//
// ---
//
// Rod response algorithm developed from sample rod response colors by
// Larry Robinson on this page:
// - https://midimagic.sgc-hosting.com/huvision.htm
//
// Blue Cone Monchromat filter developed with the help of Dean Monthei.
// The descriptions and images were quite useful:
// - https://www.blueconemonochromacy.org/know-more/colorblindess/


#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

extern "C" {

	namespace coreimage {

		float sat(float3 c)
		{
			float cmax = max(max(c.r, c.g), c.b);
			float cmin = min(min(c.r, c.g), c.b);
			float C = (cmax - cmin);
			float V = cmax;
			return C / V;
		}
		float bcm_sat(float3 c)
		{
			float cmax = max(c.g, c.b);
			float cmin = min(c.g, c.b);
			float C = (cmax - cmin);
			float V = cmax;
			return C / V;
		}
		float bcm_hue(float3 c)
		{
			float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
			float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

			float d = q.x - min(q.w, q.y);
			float e = 1.0e-10;
			return abs(q.z + (q.w - q.y) / (6.0 * d + e));
		}

		float4 bcm_kernel(sample_t color, float blueSensitivity, float attrib_anomalize) {
			float hue = bcm_hue(color.rgb);
			float rod;
			if (hue < 0.07) {
				// red - orange
				rod = mix(0.0, 1.0, (hue - 0.00) / (0.07 - 0.00));
			} else if (hue < 0.15) {
				// orange - yellow
				rod = mix(1.0, 0.7, (hue - 0.07) / (0.15 - 0.07));
			} else if (hue < 0.35) {
				// yellow - green
				rod = mix(0.7, 1.0, (hue - 0.15) / (0.35 - 0.15));
			} else if (hue < 0.50) {
				// green - cyan
				rod = mix(1.0, 1.0, (hue - 0.35) / (0.50 - 0.35));
			} else if (hue < 0.66) {
				// cyan - blue
				rod = mix(1.0, 0.8, (hue - 0.50) / (0.66 - 0.50));
			} else if (hue < 0.75) {
				// blue - violet
				rod = mix(0.8, 0.5, (hue - 0.66) / (0.75 - 0.66));
			} else if (hue < 0.85) {
				// violet - magenta
				rod = mix(0.5, 0.5, (hue - 0.75) / (0.85 - 0.75));
			} else {
				// magenta - red
				rod = mix(0.5, 0.0, (hue - 0.85) / (1.00 - 0.85));
			}

			float blue = color.b - max(0.0, color.g - color.b);

			float li = max(color.g, color.b);
			float saturation = mix(sat(color.rgb), bcm_sat(color.rgb), blueSensitivity);

			float aquaShift = 0.5; // make blue brigther to the normal eye by shifting it to aqua
			float3 blueYellow = normalize(float3(li-blue, li-blue + aquaShift*blue, blue));
			float3 blueYellowAdjust = mix(float3(1.0), blueYellow, blueSensitivity);

			float3 rgb = mix(float3(li), li*(rod*blueYellowAdjust), saturation);
			color.rgb = mix(color.rgb, rgb, attrib_anomalize);
			return color;
		}

	}

}
