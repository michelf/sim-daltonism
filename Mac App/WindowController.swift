
//	Copyright 2005-2017 Michel Fortin
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.

import Cocoa

class WindowController: NSWindowController, NSWindowDelegate {

	var visionType = UserDefaults.standard.integer(forKey: SimVisionTypeKey) {
		didSet {
			setDefaults()
			applyVisionType()
		}
	}

	func setDefaults() {
		UserDefaults.standard.set(visionType, forKey: SimVisionTypeKey)
	}

	fileprivate func applyVisionType() {
		guard let window = self.window else { return }
		window.title = SimVisionTypeName(visionType)
		((window.contentViewController! as! ViewController).filteredView.filter as! SimDaltonismFilter).visionType = visionType
		FilterWindowManager.shared.changedWindowController(self)
		window.invalidateRestorableState()
	}

	fileprivate static let windowLevel = NSWindow.Level(Int(CGWindowLevelForKey(CGWindowLevelKey.assistiveTechHighWindow) + 1))

    override func windowDidLoad() {
        super.windowDidLoad()
    
		// cannot set from IB:
		// Note: window level is set to 1 above Red Stripe's window level
		// so you can use the two together.
		window?.level = WindowController.windowLevel
		window?.hidesOnDeactivate = false
		window?.standardWindowButton(.zoomButton)?.isEnabled = false
		window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .participatesInCycle]
		window?.styleMask.formUnion(.nonactivatingPanel)
		window?.restorationClass = FilterWindowManager.self

		let accessory = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "WindowControls") as! NSTitlebarAccessoryViewController
		accessory.layoutAttribute = .right
		window?.addTitlebarAccessoryViewController(accessory)

		applyVisionType()
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
		state.encode(visionType, forKey: "VisionType")
	}
	func window(_ window: NSWindow, didDecodeRestorableState state: NSCoder) {
		visionType = state.decodeInteger(forKey: "VisionType")
	}

	override func showWindow(_ sender: Any?) {
		FilterWindowManager.shared.addWindowController(self)
		super.showWindow(sender)
	}

	func windowWillClose(_ notification: Notification) {
		FilterWindowManager.shared.removeWindowController(self)
	}

	@IBAction func adoptVisionTypeSetting(_ sender: NSMenuItem) {
		visionType = sender.tag
	}

	@objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.action! {
		case #selector(adoptVisionTypeSetting(_:)):
			menuItem.state = visionType == menuItem.tag ? .on : .off
			return true
		default:
			return false
		}
	}

}
