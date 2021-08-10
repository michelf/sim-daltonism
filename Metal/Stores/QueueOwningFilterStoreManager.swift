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

/// This implementation owns the DispatchQueue for
/// managing and using CIFilters.
///
/// Settings are initially pulled from the latest UserDefaults
/// or as supplied. Thereafter, it is up to the instance owner
/// to manage filter state changes.
///
public class QueueOwningFilterStoreManager: FilterStoreManager {

    public private(set) var current: FilterStore? = nil
    public let queue = DispatchQueue.uniqueUserInitiatedQueue()
    private var vision: NSInteger
    private var simulation: NSInteger

    public init(vision: NSInteger = UserDefaults.getVision(),
                simulation: NSInteger = UserDefaults.getSimulation()) {
        self.vision = vision
        self.simulation = simulation
        queue.async { [weak self] in
            self?.current = Self.simulationStore(for: simulation, vision: vision)
        }
    }

    public func setVisionFilter(to vision: NSInteger) {
        queue.async { [weak self] in
            self?.current?.setVisionFilter(to: vision)
        }
    }

    public func setSimulation(to simulation: NSInteger) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.current = Self.simulationStore(for: simulation, vision: self.vision)
        }
    }

    /// Call in the queue in which the CIFilters will be used.
    private static func simulationStore(for integer: NSInteger, vision: NSInteger) -> FilterStore {
        switch integer {
            case 0: return HCIRNFilterStore(vision: vision)
            case 1: return MachadoFilterStore(vision: vision)
            default: return HCIRNFilterStore(vision: vision)
        }
    }
}
