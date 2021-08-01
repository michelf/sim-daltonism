
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

class MonochromacyFilter: CIFilter {

    @objc dynamic var inputImage: CIImage?
    @objc dynamic let multiplierHalf3: CIVector = .init(x: 0.2126, y: 0.7152, z: 0.0722)
    @objc dynamic var intensity: Float

    init(intensity: Float) {
        self.intensity = intensity
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
        return try? CIColorKernel(functionName: "dotIntensity_kernel",
                                  fromMetalLibraryData: data,
                                  outputPixelFormat: CIFormat.RGBAh)
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
        return("Monochromacy simulation (not peer-reviewed)")
    }

}

class MachadoFilter: CIFilter {

    @objc dynamic var inputImage: CIImage?
    @objc dynamic var matrixHalf3x3: CIVector

    init(matrix3x3: [CGFloat]) {
        self.matrixHalf3x3 = .init(values: matrix3x3, count: 9)
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
        return try? CIColorKernel(functionName: "colorTransform_kernel",
                                  fromMetalLibraryData: data,
                                  outputPixelFormat: CIFormat.RGBAh)
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
                matrixHalf3x3,
            ])
    }

    override var description: String {
        return("Color blindness simulation (Machado et al.)")
    }

}
