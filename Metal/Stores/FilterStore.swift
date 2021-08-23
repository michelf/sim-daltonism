
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
/// When using a CIFilter, use the queue in this store.
///
public protocol FilterStore: AnyObject {

    init(vision: VisionType, simulation: Simulation)
    
    var visionFilter: CIFilter? { get }

    /// For thread-safe use of CIFilters
    ///
    var queue: DispatchQueue { get }

    /// Makes a thread-safe change to the current filter
    ///
    func setSimulation(to simulation: Simulation)

    /// Makes a thread-safe change to the current filter
    ///
    func setVision(to vision: VisionType)
    
    /// Applies a vision filter if available. Call on the store's queue (that creates and adjusts the filter).
    ///
    func applyFilter(to image: CIImage) -> CIImage?
}
