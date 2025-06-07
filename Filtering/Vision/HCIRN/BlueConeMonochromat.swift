import CoreImage

class BlueConeMonochromatFilter: CIFilter {

	@objc dynamic var inputImage: CIImage?
	@objc dynamic var intensity: Float
	@objc dynamic var blueSensitivity: Float

	init(blueSensitivity: Float, intensity: Float) {
		self.intensity = intensity
		self.blueSensitivity = blueSensitivity
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
			return try CIColorKernel(functionName: "bcm_kernel",
									 fromMetalLibraryData: data,
									 outputPixelFormat: CIFormat.RGBAh)
		} catch {
#if os(macOS)
			let url = Bundle.main.url(forResource: "BlueConeMonochromat", withExtension: "cikernel")!
			let source = try! String(contentsOf: url, encoding: .utf8)
			return CIColorKernel(source: source)
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
				blueSensitivity,
				intensity,
			])
	}

	override var description: String {
		return("Monochromat Filter")
	}

}
