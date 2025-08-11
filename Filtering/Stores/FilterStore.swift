
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
@preconcurrency import CoreImage

/// This implementation owns the DispatchQueue for
/// managing and using CIFilters.
///
/// Settings are initially pulled from the latest UserDefaults
/// or as supplied. Thereafter, it is up to the instance owner
/// to manage filter state changes.
///
@MainActor
public class FilterStore {

	public required init(configuration: FilterConfiguration) {
		self.configuration = configuration

		HCIRNFilterVendor.registerFilters()
		ColorToolsVendor.registerFilters()

		applyConfigurationAsync(configuration)
	}

	public var configuration: FilterConfiguration {
		didSet {
			assert(Thread.isMainThread)
			applyConfigurationAsync(configuration)
			NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
		}
	}

	/// Notification sent when the configuration is changed.
	public static let didChangeNotification = Notification.Name("FilterStoreDidChange")

	fileprivate struct Filters: Sendable {
		var oldConfig: FilterConfiguration?
		var visionFilter: CIFilter? = nil
		var stripeFilter: Stripes? = nil
		var vibrancyFilter: CIFilter? = nil
		var invertFilter: CIFilter? = nil
		var hueAdjustFilter: CIFilter? = nil
	}
	private let filters = DispatchQueueMutex(Filters(), label: FilterStore.nextDispatchQueueLabel(), qos: .userInitiated)

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

    /// Applies a vision filter if available. Thread-safe, can be called from any thread.
    ///
	nonisolated public func applyFilter(to image: CIImage) -> CIImage? {
		filters.withLock { filters in
			let cs = CGColorSpace(name: CGColorSpace.sRGB)!
			var image = image
			image = image.applying(filters.stripeFilter)
			image = image.applying(filters.hueAdjustFilter, in: cs)
			image = image.applying(filters.invertFilter, in: cs)
			image = image.applying(filters.vibrancyFilter)
			image = image.applying(filters.visionFilter)
			return image
		}
    }

}

// MARK: - Change Filters

extension FilterStore {

	private func applyConfigurationAsync(_ newConfig: FilterConfiguration) {
		filters.enqueue { filters in
			filters.changeVision(for: newConfig)
			filters.changeStripes(for: newConfig)
			filters.changeEffects(for: newConfig)
			filters.changeColorBoost(for: newConfig)
			filters.oldConfig = newConfig
		}
	}

}
extension FilterStore.Filters {

	fileprivate mutating func changeVision(for newConfig: FilterConfiguration) {
//		dispatchPrecondition(condition: .onQueue(queue))
		guard newConfig.vision != oldConfig?.vision else { return }

		if newConfig.vision == .normal {
			self.visionFilter = nil
		} else {
			self.visionFilter = CIFilter(name: newConfig.vision.ciFilterString)
		}
	}

	fileprivate mutating func changeStripes(for newConfig: FilterConfiguration) {
//		dispatchPrecondition(condition: .onQueue(queue))
		let stripeConfig = newConfig.stripeConfig
		if stripeConfig.isPassthrough && stripeFilter != nil {
			stripeFilter = nil
		} else if !stripeConfig.isPassthrough && stripeFilter == nil {
			stripeFilter = (CIFilter(name: "Stripes") as! Stripes)
		}
		stripeFilter?.config = stripeConfig
	}

	fileprivate mutating func changeEffects(for newConfig: FilterConfiguration) {
//		dispatchPrecondition(condition: .onQueue(queue))
		let needsInvert = newConfig.invertLuminance
		let needsHueAdjust = newConfig.hueShift != needsInvert
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
	}

	fileprivate mutating func changeColorBoost(for newConfig: FilterConfiguration) {
		let colorBoost = newConfig.colorBoost
		if !colorBoost && vibrancyFilter != nil {
			vibrancyFilter = nil
		} else if colorBoost && vibrancyFilter == nil {
			vibrancyFilter = CIFilter(name: "AddVibrancy")
		}
	}

}

// MARK: - Dispatch Queue Label

public extension FilterStore {

	private static let queueCount = Mutex(0)

	static func nextDispatchQueueLabel() -> String {
		let count = queueCount.withLock { $0 += 1; return $0 }
		return "\(Self.self)" + String(count)
	}
}

