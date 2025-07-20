
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

public enum VisionType: Int, CaseIterable, Sendable {
    case normal
    case deutan
    case deuteranomaly
    case protan
    case protanomaly
    case tritan
    case tritanomaly
	case achromatopsia
	case blueConeMonochromat
	case monochromeAnalogTV

    public var name: String {
        switch self {
            case .normal:               return NSLocalizedString("Normal Vision", tableName: "SimDaltonismFilter", comment: "")
            case .deutan:               return NSLocalizedString("Deuteranopia", tableName: "SimDaltonismFilter", comment: "")
            case .deuteranomaly:        return NSLocalizedString("Deuteranomaly", tableName: "SimDaltonismFilter", comment: "")
            case .protan:               return NSLocalizedString("Protanopia", tableName: "SimDaltonismFilter", comment: "")
            case .protanomaly:          return NSLocalizedString("Protanomaly", tableName: "SimDaltonismFilter", comment: "")
            case .tritan:               return NSLocalizedString("Tritanopia", tableName: "SimDaltonismFilter", comment: "")
            case .tritanomaly:          return NSLocalizedString("Tritanomaly", tableName: "SimDaltonismFilter", comment: "")
			case .blueConeMonochromat:  return NSLocalizedString("Blue Cone Monochromacy", tableName: "SimDaltonismFilter", comment: "")
            case .achromatopsia:        return NSLocalizedString("Achromatopsia", tableName: "SimDaltonismFilter", comment: "")
			case .monochromeAnalogTV:   return NSLocalizedString("Monochrome Analog TV", tableName: "SimDaltonismFilter", comment: "")
        }
    }

	public var description: String {
		switch self {
		case .normal:               return NSLocalizedString("Trichromatic: red, green, and blue cones", tableName: "SimDaltonismFilter", comment: "")
		case .deutan:               return NSLocalizedString("No green cones", tableName: "SimDaltonismFilter", comment: "")
		case .deuteranomaly:        return NSLocalizedString("Anomalous green cones", tableName: "SimDaltonismFilter", comment: "")
		case .protan:               return NSLocalizedString("No red cones", tableName: "SimDaltonismFilter", comment: "")
		case .protanomaly:          return NSLocalizedString("Anomalous red cones", tableName: "SimDaltonismFilter", comment: "")
		case .tritan:               return NSLocalizedString("No blue cones", tableName: "SimDaltonismFilter", comment: "")
		case .tritanomaly:          return NSLocalizedString("Anomalous blue cones", tableName: "SimDaltonismFilter", comment: "")
		case .blueConeMonochromat:  return NSLocalizedString("Absent or non-functionning red and green cones", tableName: "SimDaltonismFilter", comment: "")
		case .achromatopsia:        return NSLocalizedString("Absent or non-functionning cones, rods only", tableName: "SimDaltonismFilter", comment: "")
		case .monochromeAnalogTV:   return NSLocalizedString("BT.601 luma coefficients", tableName: "SimDaltonismFilter", comment: "")
		}

	}

    static let defaultValue = VisionType.normal

    init(runtime: Int) {
        self = .init(rawValue: runtime) ?? .defaultValue
    }
}

enum VisionCategory {
	case redGreen
	case blueYellow
	case monochromatism
	case other

	public var name: String {
		switch self {
		case .redGreen:       return NSLocalizedString("Red/Green Confusion", tableName: "SimDaltonismFilter", comment: "category name")
		case .blueYellow:     return NSLocalizedString("Blue/Yellow Confusion", tableName: "SimDaltonismFilter", comment: "category name")
		case .monochromatism: return NSLocalizedString("Monochromatism", tableName: "SimDaltonismFilter", comment: "category name")
		case .other:          return NSLocalizedString("Other", tableName: "SimDaltonismFilter", comment: "category name")
		}
	}
	public var description: String {
		switch self {
		case .redGreen:       return NSLocalizedString("Most common color vision deficiencies", tableName: "SimDaltonismFilter", comment: "category description")
		case .blueYellow:     return ""
		case .monochromatism: return ""
		case .other:          return ""
		}
	}
}
