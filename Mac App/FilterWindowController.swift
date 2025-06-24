
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

import Cocoa


class FilterWindowController: NSWindowController, NSWindowDelegate {

    /// Unique instance per window
	var filterStore: FilterStore = FilterStore(configuration: FilterConfiguration())

    // MARK: - User Settings

    var visionType = UserDefaults.getVision() {
        didSet {
            setVisionTypeDefault()
            applyVisionType()
        }
    }

    func setVisionTypeDefault() {
        UserDefaults.setVision(visionType)
    }

    private func applyVisionType() {
		filterStore.configuration.vision = visionType
        FilterWindowManager.shared.changedWindowController(self)
    }

    var simulation = UserDefaults.getSimulation() {
        didSet {
            setSimulationDefault()
            applySimulation()
        }
    }

    func setSimulationDefault() {
        UserDefaults.setSimulation(simulation)
    }

    fileprivate func applySimulation() {
		filterStore.configuration.simulation = simulation
    }

	func refreshScale() {
		filterStore.configuration.stripeConfig.patternScale = Float(window?.backingScaleFactor ?? 1)
	}

	@objc func refreshForFilterStoreConfiguration() {
		guard let window = self.window else { return }
		window.invalidateRestorableState()
		refreshTitle()
		refreshSubtitle()
	}

	func refreshTitle() {
		window?.title = visionType.name
	}
	func refreshSubtitle() {
		guard #available(macOS 11.0, *) else { return }
		var parts: [String] = []
		let config = filterStore.configuration
		if config.stripeConfig.redStripes != 0 {
			parts.append(NSLocalizedString("Red Stripes", comment: "window subtitle part"))
		}
		if config.stripeConfig.greenStripes != 0 {
			parts.append(NSLocalizedString("Green Stripes", comment: "window subtitle part"))
		}
		if config.stripeConfig.blueStripes != 0 {
			parts.append(NSLocalizedString("Blue Stripes", comment: "window subtitle part"))
		}
		if config.hueShift {
			parts.append(NSLocalizedString("Hue Shift", comment: "window subtitle part"))
		}
		if config.invertLuminance {
			parts.append(NSLocalizedString("Luminance Flip", comment: "window subtitle part"))
		}
		if config.colorBoost {
			parts.append(NSLocalizedString("Vibrancy Boost", comment: "window subtitle part"))
		}
		window?.subtitle = parts.joined(separator: ", ")
	}

	func windowDidChangeBackingProperties(_ notification: Notification) {
		refreshScale()
	}

    // MARK: - Manage Window

    fileprivate static let windowLevel = NSWindow.Level(Int(CGWindowLevelForKey(CGWindowLevelKey.assistiveTechHighWindow) + 1))

	var settingsAccessory: FilterSettingsController!

    override func windowDidLoad() {
        super.windowDidLoad()

		let window = window!

        // cannot set from IB:
        // Note: window level is set to 1 above Red Stripe's window level
        // so you can use the two together.
        window.level = FilterWindowController.windowLevel
		window.hidesOnDeactivate = false
		window.standardWindowButton(.zoomButton)?.isEnabled = false
        if #available(OSX 10.12, *) {
			window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .participatesInCycle]
        } else {
			window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // dragging not working with .participatesInCycle
        }
		window.restorationClass = FilterWindowManager.self
		window.styleMask.insert(.utilityWindow)

		settingsAccessory = (NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "WindowControls") as! FilterSettingsController)
		settingsAccessory.layoutAttribute = .right
		if #available(macOS 11.0, *) {
			// title bar accessory is replaced with a unified toolbar (managed by the same view controller)
			window.toolbar = settingsAccessory.makeToolbar()
			window.toolbarStyle = .unifiedCompact
			window.subtitle = "Red  Green  Blue  Hue Shift  Luminance Flip  Vibrancy Boost"
		} else {
			window.addTitlebarAccessoryViewController(settingsAccessory)
		}

        applyVisionType()
		refreshScale()

		NotificationCenter.default.addObserver(self, selector: #selector(refreshForFilterStoreConfiguration), name: FilterStore.didChangeNotification, object: filterStore)
		refreshForFilterStoreConfiguration()
    }

    /// Position the window so it has a different origin than other filter
    /// windows based on the registered list of window controllers in
    /// `FilterWindowManager`.
    func cascade() {
        var windowControllers = FilterWindowManager.shared.windowControllers
        windowControllers.remove(self)
    baseLoop:
        while !windowControllers.isEmpty {
            guard let frame = window?.frame else { return }
            for otherController in windowControllers {
                if otherController.window?.frame.origin == frame.origin {
                    window?.setFrameOrigin(frame.offsetBy(dx: 30, dy: -30).origin)
                    windowControllers.remove(otherController)
                    continue baseLoop
                }
            }
            break // check all remaining controllers
        }
    }

    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        WindowRestoration.encodeRestorable(state: state, visionType, simulation)
    }
    
    func window(_ window: NSWindow, didDecodeRestorableState state: NSCoder) {
        (visionType, simulation) = WindowRestoration.decodeRestorable(state: state)
    }

    override func showWindow(_ sender: Any?) {
        FilterWindowManager.shared.addWindowController(self)
        super.showWindow(sender)
    }

    func windowWillClose(_ notification: Notification) {
        FilterWindowManager.shared.removeWindowController(self)
    }

    // MARK: - Menu Intents (Unique state per window)

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
		case #selector(adoptVisionTypeSetting)?:
			menuItem.state = visionType.rawValue == menuItem.tag ? .on : .off
			return true

		case #selector(adoptSimulationSetting)?:
			menuItem.state = simulation.rawValue == menuItem.tag ? .on : .off
			return true

		case #selector(adoptRedStripeSetting)?:
			let current = Int(filterStore.configuration.stripeConfig.redStripes)
			menuItem.state = current == menuItem.tag ? .on : .off
			return true
		case #selector(adoptGreenStripeSetting)?:
			let current = Int(filterStore.configuration.stripeConfig.greenStripes)
			menuItem.state = current == menuItem.tag ? .on : .off
			return true
		case #selector(adoptBlueStripesSetting)?:
			let current = Int(filterStore.configuration.stripeConfig.blueStripes)
			menuItem.state = current == menuItem.tag ? .on : .off
			return true
		case #selector(toggleInvertHue)?:
			let current = filterStore.configuration.hueShift
			menuItem.state = current ? .on : .off
			return true
		case #selector(toggleInvertLuminance)?:
			let current = filterStore.configuration.invertLuminance
			menuItem.state = current ? .on : .off
			return true
		case #selector(toggleSaturationBoost)?:
			let current = filterStore.configuration.colorBoost
			menuItem.state = current ? .on : .off
			return true
		default:
			return false
		}
    }

	@IBAction func adoptVisionTypeSetting(_ sender: NSMenuItem) {
		visionType = .init(rawValue: sender.tag) ?? .defaultValue
	}

    @IBAction func adoptSimulationSetting(_ sender: NSMenuItem) {
        simulation = .init(runtime: sender.tag)
    }

	@IBAction func adoptRedStripeSetting(_ sender: NSMenuItem) {
		filterStore.configuration.stripeConfig.redStripes = Float(sender.tag)
	}

	@IBAction func adoptGreenStripeSetting(_ sender: NSMenuItem) {
		filterStore.configuration.stripeConfig.greenStripes = Float(sender.tag)
	}

	@IBAction func adoptBlueStripesSetting(_ sender: NSMenuItem) {
		filterStore.configuration.stripeConfig.blueStripes = Float(sender.tag)
	}

	@IBAction func toggleInvertHue(_ sender: NSMenuItem) {
		let setting = !(sender.state == .on ? true : false)
		filterStore.configuration.hueShift = setting
	}

	@IBAction func toggleInvertLuminance(_ sender: NSMenuItem) {
		let setting = !(sender.state == .on ? true : false)
		filterStore.configuration.invertLuminance = setting
	}

	@IBAction func toggleSaturationBoost(_ sender: NSMenuItem) {
		let setting = !(sender.state == .on ? true : false)
		filterStore.configuration.colorBoost = setting
	}


}
