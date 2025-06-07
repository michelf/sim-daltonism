
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

/// [Citation](https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/CVD_Simulation.html)
class MachadoFilterVendor: NSObject, CIFilterConstructor {

    static func registerFilters() {
        let classAttributes = [kCIAttributeFilterCategories: ["CustomFilters"]]

        let monochrome: Set<VisionType> = [
            .achromatopsia,
            .achromatopsiaPartial
        ]

        VisionType.allCases.forEach { vision in

            if monochrome.contains(vision) {

                MonochromacyFilter.registerName(
                    vision.ciFilterString,
                    constructor: MachadoFilterVendor(),
                    classAttributes: classAttributes
                )

            } else {

                MachadoFilter.registerName(
                    vision.ciFilterString,
                    constructor: MachadoFilterVendor(),
                    classAttributes: classAttributes
                )
            }
        }

    }

    func filter(withName name: String) -> CIFilter? {
        var matrix = [CGFloat]()

        let vision = VisionType(ciFilterVendor: name)

        switch vision {
            case .deutan:
                matrix = [0.367322, 0.280085, -0.011820, 0.860646, 0.672501, 0.042940, -0.227968, 0.047413, 0.968881]

            case .deuteranomaly:
                matrix = [0.457771, 0.226409, -0.011595, 0.731899, 0.731012, 0.034333, -0.189670, 0.042579, 0.977261]

            case .protan:
                matrix = [0.152286, 0.114503, -0.003882, 1.052583, 0.786281, -0.048116, -0.204868, 0.099216, 1.051998]

            case .protanomaly:
                matrix = [0.319627, 0.106241, -0.007025, 0.849633, 0.815969, -0.028051, -0.169261, 0.077790, 1.035076]

            case .tritan:
                matrix = [1.255528, -0.078411, 0.004733, -0.076749, 0.930809, 0.691367, -0.178779, 0.147602, 0.303900]

            case .tritanomaly:
                matrix = [1.193214, -0.058496, -0.002346, -0.109812, 0.979410, 0.403492, -0.083402, 0.079086, 0.598854]

            case .achromatopsia:
                return MonochromacyFilter(intensity: 1)

            case .achromatopsiaPartial:
                return MonochromacyFilter(intensity: 0.66)

            default: return nil
        }

        return MachadoFilter(matrix3x3: matrix)
    }
}
