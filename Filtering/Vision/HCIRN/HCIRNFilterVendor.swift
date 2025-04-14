
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
//  ==========================================================================
//    ADDITIONAL CONDITIONS
//    The color blindness simulation algorithm in this file is a derivative work
//    of the color_blind_sim javascript function from the Color Laboratory.
//    The original copyright and licensing terms below apply *in addition* to
//    the Apache License 2.0.
//    Original: http://colorlab.wickline.org/colorblind/colorlab/engine.js
//  --------------------------------------------------------------------------
//    The color_blind_sims() JavaScript function in the is
//    copyright (c) 2000-2001 by Matthew Wickline and the
//    Human-Computer Interaction Resource Network ( http://hcirn.com/ ).
//
//    The color_blind_sims() function is used with the permission of
//    Matthew Wickline and HCIRN, and is freely available for non-commercial
//    use. For commercial use, please contact the
//    Human-Computer Interaction Resource Network ( http://hcirn.com/ ).
//    (This notice constitutes permission for commercial use from Matthew
//    Wickline, but you must also have permission from HCIRN.)
//    Note that use of the color laboratory hosted at aware.hwg.org does
//    not constitute commercial use of the color_blind_sims()
//    function. However, use or packaging of that function (or a derivative
//    body of code) in a for-profit piece or collection of software, or text,
//    or any other for-profit work *shall* constitute commercial use.
//
//    20151129 UPDATE [by Matthew Wickline]
//        HCIRN appears to no longer exist. This makes it impractical
//        for users to obtain permission from HCIRN in order to use
//        color_blind_sims() for commercial works. Instead:
//
//        This work is licensed under a
//        Creative Commons Attribution-ShareAlike 4.0 International License.
//        http://creativecommons.org/licenses/by-sa/4.0/

import Foundation
import CoreImage

class HCIRNFilterVendor: NSObject, CIFilterConstructor {

    static func registerFilters() {
        let classAttributes = [kCIAttributeFilterCategories: ["CustomFilters"]]

        VisionType.allCases.forEach { vision in
            HCIRN.registerName(
                vision.ciFilterString,
                constructor: HCIRNFilterVendor(),
                classAttributes: classAttributes
            )
        }
    }

    func filter(withName name: String) -> CIFilter? {
        var cp = CIVector()
        var ab = CIVector()
        var ae = CIVector()
        var anomalize = Float(0)

        let vision = VisionType(ciFilterVendor: name)

        switch vision {
            case .deutan: fallthrough
            case .deuteranomaly:
                cp = .init(x: 1.14, y: -0.14)
                ab = .init(x: 0.102776, y: 0.102864)
                ae = .init(x: 0.505845, y: 0.493211)

            case .protan: fallthrough
            case .protanomaly:
                cp = .init(x: 0.735, y: 0.265)
                ab = .init(x: 0.115807, y: 0.073581)
                ae = .init(x: 0.471899, y: 0.527051)

            case .tritan: fallthrough
            case .tritanomaly:
                cp = .init(x: 0.171, y: -0.003)
                ab = .init(x: 0.045391, y: 0.294976)
                ae = .init(x: 0.665764, y: 0.334011)

            case .monochromat: fallthrough
            case .monochromacyPartial:
                cp = .init(x: 0, y: 0)
                ab = .init(x: 0, y: 0)
                ae = .init(x: 0, y: 0)

            default: return nil
        }

        switch vision {
            case .deutan: fallthrough
            case .protan: fallthrough
            case .tritan:
                anomalize = 1.0

            case .deuteranomaly: fallthrough
            case .protanomaly: fallthrough
            case .tritanomaly:
                anomalize = 0.66

            case .monochromat:
                anomalize = -1
            case .monochromacyPartial:
                anomalize = -0.66

            default: return nil
        }

        return HCIRN(cp: cp, ab: ab, ae: ae, anomalize: anomalize)
    }
}
