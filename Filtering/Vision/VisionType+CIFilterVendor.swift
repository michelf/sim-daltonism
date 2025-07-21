
//  Copyright 2005-2025 Michel Fortin
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Foundation

extension VisionType {

    /// Convenience for working CIFilterConstructor's stringly typed filter creation method: 'func filter(withName name: String) -> CIFilter?'
    public init(ciFilterVendor string: String) {
        let match = VisionType.allCases
            .first { $0.ciFilterString == string }
        self = match ?? .normal
    }

    /// Convenience for working CIFilterConstructor's stringly typed filter creation method: 'func filter(withName name: String) -> CIFilter?'
    public var ciFilterString: String {
        switch self {
		case .normal: return "Normal"
		case .deutan: return "Deutan"
		case .deuteranomaly: return "Deutanomaly"
		case .protan: return "Protan"
		case .protanomaly: return "Protanomaly"
		case .tritan: return "Tritan"
		case .tritanomaly: return "Tritanomaly"
		case .achromatopsia: return "Achromatopsia"
		case .blueConeMonochromat: return "BlueConeMonochromat"
		case .monochromeAnalogTV: return "monochromeAnalogTV"
		}
    }
}
