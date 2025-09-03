//    Copyright 2005-2025 Michel Fortin
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

		float4 dotIntensity_kernel(sample_t color, float3 transform, float intensity) {
			float m = dot(color.rgb, transform);
			float3 transformed = float3(m,m,m);
			float3 mixed = mix(color.rgb, transformed, intensity);
			return float4(mixed, color.a);
		}

	}
}
