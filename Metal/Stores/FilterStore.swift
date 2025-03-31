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

	private(set) var visionFilter: CIFilter? = nil
	private(set) var stripeFilter: Stripes? = nil
	private(set) var vibrancyFilter: CIFilter? = nil
	private(set) var invertFilter: CIFilter? = nil
	private(set) var hueAdjustFilter: CIFilter? = nil
	private let queue = DispatchQueue(label: FilterStore.nextDispatchQueueLabel(), qos: .userInitiated)
    private var vision: VisionType
	internal var stripeConfig = StripeConfig()
	internal var colorEffects: (invertLuminance: Bool, hueShift: Bool) = (false, false)
	internal var colorBoost: Bool = false

    public required init(vision: VisionType = UserDefaults.getVision(),
                         simulation: Simulation = UserDefaults.getSimulation()) {
        self.vision = vision
        queue.async { [weak self] in
            self?.setSimulation(to: simulation)

			VisionToolsVendor.registerFilters()
        }
    }
}

// MARK: - Apply Filter

extension CIImage {

	fileprivate func withColorspace(_ colorspace: CGColorSpace, task: (inout CIImage) -> ()) -> CIImage {
		var image = self.matchedFromWorkingSpace(to: colorspace) ?? self
		task(&image)
		return image.matchedToWorkingSpace(from: colorspace) ?? image
	}
	fileprivate func applying(_ filter: CIFilter?) -> CIImage {
		filter?.setValue(self, forKey: kCIInputImageKey)
		return filter?.outputImage ?? self
	}
	fileprivate func applying(_ filter: CIFilter?, in colorspace: CGColorSpace) -> CIImage {
		withColorspace(colorspace) { image in
			image = image.applying(filter)
		}
	}

}

extension FilterStore {

    /// Applies a vision filter if available.
    /// Call on the queue in which the store was created.
    ///
    public func applyFilter(to image: CIImage) -> CIImage? {
		queue.sync {
			let cs = CGColorSpace(name: CGColorSpace.sRGB)!
			var image = image
			image = image.applying(stripeFilter)
			image = image.applying(hueAdjustFilter, in: cs)
			image = image.applying(invertFilter, in: cs)
			image = image.applying(vibrancyFilter)
			image = image.applying(visionFilter)
			return image
		}
    }
}

// MARK: - Change Filters

extension FilterStore {

    public func setVision(to vision: VisionType) {
        queue.async { [weak self] in
			guard let self = self else { return }
			self.visionFilter = CIFilter(name: vision.ciFilterString)
			self.vision = vision
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

	public func changeStripes(_ task: @escaping (inout StripeConfig) -> ()) {
		queue.async { [weak self] in
			guard let self else { return }
			task(&stripesConfig_inQueue)
		}
	}

	private var stripesConfig_inQueue: StripeConfig {
		get {
			assert(Thread.isMainThread == false)
			return self.stripeFilter?.config ?? StripeConfig()
		}
		set {
			assert(Thread.isMainThread == false)
			if newValue.isPassthrough && stripeFilter != nil {
				stripeFilter = nil
			} else if !newValue.isPassthrough && stripeFilter == nil {
				stripeFilter = (CIFilter(name: "Stripes") as! Stripes)
			}
			stripeFilter?.config = newValue
			self.stripeConfig = newValue
		}
	}

	public func changeEffects(_ task: @escaping (inout (invertLuminance: Bool, hueShift: Bool)) -> ()) {
		queue.async { [weak self] in
			guard let self else { return }
			task(&colorEffects_inQueue)
		}
	}

	private var colorEffects_inQueue: (invertLuminance: Bool, hueShift: Bool) {
		get {
			assert(Thread.isMainThread == false)
			return colorEffects
		}
		set {
			assert(Thread.isMainThread == false)
			colorEffects = newValue
			let needsInvert = newValue.invertLuminance
			let needsHueAdjust = newValue.hueShift != needsInvert
			if !needsInvert && invertFilter != nil {
				invertFilter = nil
			} else if needsInvert && invertFilter == nil {
				invertFilter = CIFilter(name: "CIColorInvert")
			}
			if !needsHueAdjust && hueAdjustFilter != nil {
				hueAdjustFilter = nil
			} else if needsHueAdjust && hueAdjustFilter == nil {
				let hueAdjustFilter = CIFilter(name: "InvertHue")
				self.hueAdjustFilter = hueAdjustFilter
			}
			colorEffects = newValue
		}
	}

	public func changeColorBoost(_ task: @escaping (inout Bool) -> ()) {
		queue.async { [weak self] in
			guard let self else { return }
			task(&colorBoost_inQueue)
		}
	}

	private var colorBoost_inQueue: Bool {
		get {
			assert(Thread.isMainThread == false)
			return self.colorBoost
		}
		set {
			assert(Thread.isMainThread == false)
			colorBoost = newValue
			if !newValue && vibrancyFilter != nil {
				vibrancyFilter = nil
			} else if newValue && vibrancyFilter == nil {
				vibrancyFilter = CIFilter(name: "AddVibrancy")
			}
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

