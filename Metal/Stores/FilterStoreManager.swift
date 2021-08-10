
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

/// Makes, swaps, and adjusts FilterStores with thread safety.
/// When using CIFilters, use the queue in this Manager.
///
public protocol FilterStoreManager: AnyObject {

    /// For thread-safe use of CIFilters
    ///
    var queue: DispatchQueue { get }

    /// Coordinates the instantiation and setting of CIFilters
    /// relevant to one simulation (e.g., Wickline).
    /// This store is created asynchronously, so it may not be
    /// available exactly when the Manager is created.
    ///
    var current: FilterStore? { get }

    /// Makes a thread-safe change to the current filter
    ///
    func setVisionFilter(to vision: VisionType)

    /// Makes a thread-safe change to the current filter
    ///
    func setSimulation(to simulation: Simulation)
}
