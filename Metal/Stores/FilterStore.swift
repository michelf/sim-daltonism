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

/// This implementation owns the DispatchQueue for
/// managing and using CIFilters.
///
/// Settings are initially pulled from the latest UserDefaults
/// or as supplied. Thereafter, it is up to the instance owner
/// to manage filter state changes.
///
public class FilterStore {

    public private(set) var visionFilter: CIFilter? = nil
	private let queue = DispatchQueue(label: FilterStore.nextDispatchQueueLabel(), qos: .userInitiated)
    private var vision: VisionType

    public required init(vision: VisionType = UserDefaults.getVision(),
                         simulation: Simulation = UserDefaults.getSimulation()) {
        self.vision = vision
        queue.async { [weak self] in
            self?.setSimulation(to: simulation)
        }
    }
}

// MARK: - Apply Filter

extension FilterStore {

    /// Applies a vision filter if available.
    /// Call on the queue in which the store was created.
    ///
    public func applyFilter(to image: CIImage) -> CIImage? {
		queue.sync {
			visionFilter?.setValue(image, forKey: kCIInputImageKey)
			return visionFilter?.outputImage
		}
    }
}

// MARK: - Change Filters

extension FilterStore {

    public func setVision(to vision: VisionType) {
        queue.async { [weak self] in
            self?.visionFilter = CIFilter(name: vision.ciFilterString)
            self?.vision = vision
        }
    }

    public func setSimulation(to simulation: Simulation) {
        queue.async { [weak self] in
            guard let self = self else { return }
            switch simulation {
                case .wicklineHCIRN: HCIRNFilterVendor.registerFilters()
                case .machadoEtAl: MachadoFilterVendor.registerFilters()
            }
            self.visionFilter = CIFilter(name: self.vision.ciFilterString)
        }
    }
}

// MARK: - Dispatch Queue Label

public extension FilterStore {

	private static var queueCount = 0

	static func nextDispatchQueueLabel() -> String {
		queueCount += 1
		return "\(Self.self)" + String(queueCount)
	}
}

