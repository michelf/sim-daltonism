#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

extern "C" {

#if __CIKERNEL_METAL_VERSION__ < 200
	// missing typedef in older metal
	typedef half4 sample_h;
#endif

    namespace coreimage {
        half4 colorTransform_kernel(sample_h color, half3x3 transform) {
            half3 transformed = transform * color.rgb;
            return half4(transformed, color.a);
        }
    }

    namespace coreimage {
        half4 dotIntensity_kernel(sample_h color, half3 transform, half intensity) {
            half3 transformed = dot(color.rgb, transform);
            half3 mixed = mix(color.rgb, transformed, intensity);
            return half4(mixed, color.a);
        }
    }
}
