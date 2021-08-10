
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

/// A FilterStore controls sets of CIFilters for one simulation (e.g., Machado, Wickline/HCIRN) that are accessed by a Metal renderer.
///
public protocol FilterStore: AnyObject {

    init(vision: NSInteger)
    
    var visionFilter: CIFilter? { get }
    var visionSimulation: NSInteger { get }

    /// Call this async on the queue in which the store was created
    ///
    func setVisionFilter(to vision: NSInteger)
    
    /// Applies a vision filter if available.
    /// Call on the queue in which the store was created.
    ///
    func applyFilter(to image: CIImage) -> CIImage?
}
