
//    Copyright 2005-2017 Michel Fortin
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

class ColorToolsVendor: NSObject, CIFilterConstructor {

    static func registerFilters() {
        let classAttributes = [kCIAttributeFilterCategories: ["CustomFilters"]]
		Stripes.registerName("Stripes", constructor: ColorToolsVendor(), classAttributes: classAttributes)
		Stripes.registerName("AddVibrancy", constructor: ColorToolsVendor(), classAttributes: classAttributes)
		Stripes.registerName("InvertHue", constructor: ColorToolsVendor(), classAttributes: classAttributes)
		Stripes.registerName("InvertLuminance", constructor: ColorToolsVendor(), classAttributes: classAttributes)
    }

    func filter(withName name: String) -> CIFilter? {
		switch name {
		case "Stripes":
			return Stripes(showRed: 1, showGreen: 1, showBlue: 1, patternScale: 2)
		case "AddVibrancy":
			return AddVibrancy()
		case "InvertHue":
			return InvertHue()
		default:
			return nil
		}
    }
}
