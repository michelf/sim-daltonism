
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

func SimVisionTypeName(_ integer: NSInteger) -> String {
    switch integer {
        case 0:
            return NSLocalizedString("Normal Vision", tableName: "SimDaltonismFilter", comment: "")
        case 1:
            return NSLocalizedString("Deuteranopia", tableName: "SimDaltonismFilter", comment: "")
        case 2:
            return NSLocalizedString("Deuteranomaly", tableName: "SimDaltonismFilter", comment: "")
        case 3:
            return NSLocalizedString("Protanopia", tableName: "SimDaltonismFilter", comment: "")
        case 4:
            return NSLocalizedString("Protanomaly", tableName: "SimDaltonismFilter", comment: "")
        case 5:
            return NSLocalizedString("Tritanopia", tableName: "SimDaltonismFilter", comment: "")
        case 6:
            return NSLocalizedString("Tritanomaly", tableName: "SimDaltonismFilter", comment: "")
        case 7:
            return NSLocalizedString("Monochromacy", tableName: "SimDaltonismFilter", comment: "")
        case 8:
            return NSLocalizedString("Partial Monochromacy", tableName: "SimDaltonismFilter", comment: "")

        default: return "Error"
    }
}
