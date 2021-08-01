
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

/// Swaps between FilterStores. A FilterStore controls sets of CIFilters for one simulation (e.g., Machado, Wickline/HCIRN) that are accessed by a Metal renderer.
public class FilterStoreManager {

    public static fileprivate(set) var shared = FilterStoreManager(vision: 0, simulation: 0)

    @discardableResult
    public static func makeShared(vision: NSInteger, simulation: NSInteger) -> FilterStoreManager {
        FilterStoreManager.shared = FilterStoreManager(vision: vision, simulation: simulation)
        return Self.shared
    }

    private init(vision: NSInteger, simulation: NSInteger) {
        self.current = Self.simulationStore(for: simulation, vision: vision)
    }

    public private(set) var current: FilterStore

    public func setVisionFilter(to vision: NSInteger) {
        current.setVisionFilter(to: vision)
    }

    public func setSimulation(to simulation: NSInteger) {
        current = Self.simulationStore(for: simulation, vision: current.visionSimulation)
    }

    private static func simulationStore(for integer: NSInteger, vision: NSInteger) -> FilterStore {
        switch integer {
            case 0: return HCIRNFilterStore(vision: vision)
            case 1: return MachadoFilterStore(vision: vision)
            default: return HCIRNFilterStore(vision: vision)
        }
    }
}
