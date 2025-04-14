
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

class AddVibrancy: CIFilter {

    @objc dynamic var inputImage: CIImage?

	override init() {
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("\(#file) coder not implemented") }

    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "AddVibrancy",
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
			return try CIColorKernel(functionName: "addVibrancy_kernel",
								fromMetalLibraryData: data,
								outputPixelFormat: CIFormat.RGBAh)
		} catch {
			#if os(macOS)
			let url = Bundle.main.url(forResource: "AddVibrancy", withExtension: "cikernel")!
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
            ])
    }

    override var description: String {
        return("Color oversaturation aid")
    }

}
