
//    Copyright 2005-2021 Michel Fortin
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

import Foundation
import CoreImage

public struct StripeConfig {
	var redStripes: Float = 0
	var greenStripes: Float = 0
	var blueStripes: Float = 0
	var patternScale: Float = 1

	var isPassthrough: Bool {
		redStripes == 0 && greenStripes == 0 && blueStripes == 0
	}
}

class Stripes: CIFilter {

    @objc dynamic var inputImage: CIImage?
    @objc dynamic var showRed: Float
    @objc dynamic var showGreen: Float
    @objc dynamic var showBlue: Float
    @objc dynamic var patternScale: Float

	var config: StripeConfig {
		get {
			StripeConfig(redStripes: showRed, greenStripes: showGreen, blueStripes: showBlue, patternScale: patternScale)

		}
		set {
			showRed = newValue.redStripes
			showGreen = newValue.greenStripes
			showBlue = newValue.blueStripes
			patternScale = newValue.patternScale
		}
	}

    init(showRed: Float, showGreen: Float, showBlue: Float, patternScale: Float) {
        self.showRed = showRed
        self.showGreen = showGreen
        self.showBlue = showBlue
        self.patternScale = patternScale
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("\(#file) coder not implemented") }

    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Stripes",
            "inputImage": [
                kCIAttributeIdentity: 0,
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Image",
                kCIAttributeType: kCIAttributeTypeImage],
        ]
    }

    private lazy var kernel: CIKernel? = {
        guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let data = try? Data(contentsOf: url)
        else { return nil }
		do {
			#if os(macOS)
			if forceOpenGL { throw MetalDisabledError() }
			#endif
			return try CIKernel(functionName: "stripes_kernel",
								fromMetalLibraryData: data,
								outputPixelFormat: CIFormat.RGBAh)
		} catch {
			#if os(macOS)
			let url = Bundle.main.url(forResource: "Stripes", withExtension: "cikernel")!
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
				showRed,
				showGreen,
				showBlue,
				patternScale
            ])
    }

    override var description: String {
        return("Color stripes aid")
    }

}
