
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

class HCIRN: CIFilter {

    @objc dynamic var inputImage: CIImage?
    @objc dynamic var ATTRIB_CP_UV: CIVector
    @objc dynamic var ATTRIB_AB_UV: CIVector
    @objc dynamic var ATTRIB_AE_UV: CIVector
    @objc dynamic var ATTRIB_ANOMALIZE: Float

    init(cp: CIVector, ab: CIVector, ae: CIVector, anomalize: Float) {
        self.ATTRIB_CP_UV = cp
        self.ATTRIB_AB_UV = ab
        self.ATTRIB_AE_UV = ae
        self.ATTRIB_ANOMALIZE = anomalize
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("\(#file) coder not implemented") }

    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "HICRN",

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
        return try? CIColorKernel(functionName: "hcirn_kernel",
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
                ATTRIB_CP_UV,
                ATTRIB_AB_UV,
                ATTRIB_AE_UV,
                ATTRIB_ANOMALIZE
            ])
    }

    override var description: String {
        return("Machado simulation of tritanopia")
    }

}
