import CoreImage

class MonochromeFilter: CIFilter {

	@objc dynamic var inputImage: CIImage?
	@objc dynamic let multiplierHalf3: CIVector
	@objc dynamic var intensity: Float

	init(coefficients: (r: CGFloat, g: CGFloat, b: CGFloat), intensity: Float) {
		self.intensity = intensity
		self.multiplierHalf3 = CIVector(x: coefficients.r, y: coefficients.g, z: coefficients.b)
		super.init()
	}

	required init?(coder: NSCoder) { fatalError("\(#file) coder not implemented") }

	override var attributes: [String : Any] {
		return [
			kCIAttributeFilterDisplayName: "Monochromacy",

			"inputImage": [
				kCIAttributeIdentity: 0,
				kCIAttributeClass: "CIImage",
				kCIAttributeDisplayName: "Image",
				kCIAttributeType: kCIAttributeTypeImage],
		]
	}

	private lazy var kernel: CIColorKernel? = {
		guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
			  let data = try? Data(contentsOf: url)
		else { return nil }
		do {
#if os(macOS)
			if forceOpenGL { throw MetalDisabledError() }
#endif
			return try CIColorKernel(functionName: "dotIntensity_kernel",
									 fromMetalLibraryData: data,
									 outputPixelFormat: CIFormat.RGBAh)
		} catch {
#if os(macOS)
			return CIColorKernel(source: """
			kernel float4 dotIntensity_kernel(__sample color, float3 transform, float intensity) {
			 float m = dot(color.rgb, transform);
			 float3 transformed = float3(m,m,m);
			 float3 mixed = mix(color.rgb, transformed, intensity);
			 return float4(mixed, color.a);
			}
			""")
#else
			fatalError("Failed to create CI kernel for \(Self.self): \(error)")
#endif
		}
	}()

	override var outputImage: CIImage? {
		guard let kernel = kernel,
			  let image = inputImage
		else { return nil }

		return kernel.apply(
			extent: image.extent,
			roiCallback: { (_, _) in .null },
			arguments: [
				CISampler(image: image),
				multiplierHalf3,
				intensity,
			])
	}

	override var description: String {
		return("Monochrome Filter")
	}

}
