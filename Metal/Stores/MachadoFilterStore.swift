
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

public class MachadoFilterStore: FilterStore {

    public private(set) var visionFilter: CIFilter? = nil
    public private(set) var visionSimulation: NSInteger = 1

    public required init(vision: NSInteger) {
        MachadoFilterVendor.registerFilters()
        setVisionFilter(to: vision)
    }
}

public extension MachadoFilterStore {

    /// Call this async on the queue in which the store was created
    ///
    func setVisionFilter(to vision: NSInteger) {
        visionSimulation = vision
        visionFilter = loadFilter(for: vision)

    }

    /// Applies a vision filter if available.
    /// Call on the queue in which the store was created.
    ///
    func applyFilter(to image: CIImage) -> CIImage? {
        visionFilter?.setValue(image, forKey: kCIInputImageKey)
        return visionFilter?.outputImage
    }
}

private extension MachadoFilterStore {

    func loadFilter(for vision: NSInteger) -> CIFilter? {
        let vendor = MachadoFilterVendor.self
        switch vision {

            case 0: return nil

            case 1: return CIFilter(name: vendor.DeutanFilterName)
            case 2: return CIFilter(name: vendor.DeutanomalyFilterName)

            case 3: return CIFilter(name: vendor.ProtanFilterName)
            case 4: return CIFilter(name: vendor.ProtanomalyFilterName)

            case 5: return CIFilter(name: vendor.TritanFilterName)
            case 6: return CIFilter(name: vendor.TritanomalyFilterName)

            case 7: return CIFilter(name: vendor.MonochromatFilterName)
            case 8: return CIFilter(name: vendor.PartialMonochromacyFilterName)

            default: return nil
        }
    }
}
