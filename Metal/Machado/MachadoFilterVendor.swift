
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

    public static let MonochromatFilterName = "Monochromat"
    public static let TritanFilterName = "Tritan"
    public static let DeutanFilterName = "Deutan"
    public static let ProtanFilterName = "Protan"

    public static let PartialMonochromacyFilterName = "PartialMonochromacy"
    public static let TritanomalyFilterName = "Tritanomaly"
    public static let DeutanomalyFilterName = "Deutanomaly"
    public static let ProtanomalyFilterName = "Protanomaly"

    static func registerFilters() {
        let classAttributes = [kCIAttributeFilterCategories: ["CustomFilters"]]

        MonochromacyFilter.registerName(
            MonochromatFilterName,
            constructor: MachadoFilterVendor(),
            classAttributes: classAttributes
        )

        MachadoFilter.registerName(
            TritanFilterName,
            constructor: MachadoFilterVendor(),
            classAttributes: classAttributes
        )

        MachadoFilter.registerName(
            DeutanFilterName,
            constructor: MachadoFilterVendor(),
            classAttributes: classAttributes
        )

        MachadoFilter.registerName(
            ProtanFilterName,
            constructor: MachadoFilterVendor(),
            classAttributes: classAttributes
        )

        MonochromacyFilter.registerName(
            PartialMonochromacyFilterName,
            constructor: MachadoFilterVendor(),
            classAttributes: classAttributes
        )

        MachadoFilter.registerName(
            TritanomalyFilterName,
            constructor: MachadoFilterVendor(),
            classAttributes: classAttributes
        )

        MachadoFilter.registerName(
            DeutanomalyFilterName,
            constructor: MachadoFilterVendor(),
            classAttributes: classAttributes
        )

        MachadoFilter.registerName(
            ProtanomalyFilterName,
            constructor: MachadoFilterVendor(),
            classAttributes: classAttributes
        )
    }

    func filter(withName name: String) -> CIFilter? {
        var matrix = [CGFloat]()

        switch name {
            case Self.DeutanFilterName:
                matrix = [0.367322, 0.280085, -0.011820, 0.860646, 0.672501, 0.042940, -0.227968, 0.047413, 0.968881]

            case Self.DeutanomalyFilterName:
                matrix = [0.457771, 0.226409, -0.011595, 0.731899, 0.731012, 0.034333, -0.189670, 0.042579, 0.977261]

            case Self.ProtanFilterName:
                matrix = [0.152286, 0.114503, -0.003882, 1.052583, 0.786281, -0.048116, -0.204868, 0.099216, 1.051998]

            case Self.ProtanomalyFilterName:
                matrix = [0.319627, 0.106241, -0.007025, 0.849633, 0.815969, -0.028051, -0.169261, 0.077790, 1.035076]

            case Self.TritanFilterName:
                matrix = [1.255528, -0.078411, 0.004733, -0.076749, 0.930809, 0.691367, -0.178779, 0.147602, 0.303900]

            case Self.TritanomalyFilterName:
                matrix = [1.193214, -0.058496, -0.002346, -0.109812, 0.979410, 0.403492, -0.083402, 0.079086, 0.598854]

            case Self.MonochromatFilterName:
                return MonochromacyFilter(intensity: 1)

            case Self.PartialMonochromacyFilterName:
                return MonochromacyFilter(intensity: 0.66)

            default: return nil
        }

        return MachadoFilter(matrix3x3: matrix)
    }
}
