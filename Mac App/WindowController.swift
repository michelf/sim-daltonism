
//	Copyright 2005-2016 Michel Fortin
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

private var globalFilterWindowCount = 0

class WindowController: NSWindowController, NSWindowDelegate {

	var visionType = UserDefaults.standard.integer(forKey: SimVisionTypeKey) {
		didSet {
			UserDefaults.standard.set(visionType, forKey: SimVisionTypeKey)
			applyVisionType()
		}
	}

	private func applyVisionType() {
		window?.title = SimVisionTypeName(visionType)
		((window!.contentViewController! as! ViewController).filteredView.filter as! SimDaltonismFilter).visionType = visionType
	}

    override func windowDidLoad() {
        super.windowDidLoad()
    
		// cannot set from IB:
		// Note: window level is set to 1 above Red Stripe's window level
		// so you can use the two together.
		window?.level = Int(CGWindowLevelForKey(CGWindowLevelKey.assistiveTechHighWindow) + 1)
		window?.hidesOnDeactivate = false
		window?.standardWindowButton(.zoomButton)?.isEnabled = false
		window?.isMovable = false

		let accessory = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "WindowControls") as! NSTitlebarAccessoryViewController
		accessory.layoutAttribute = .right
		window?.addTitlebarAccessoryViewController(accessory)

		applyVisionType()

		globalFilterWindowCount += 1
    }

	func windowWillClose(_ notification: Notification) {
		// quit app when last window closes
		globalFilterWindowCount -= 1
		if globalFilterWindowCount <= 0 {
			DispatchQueue.main.async {
				NSApplication.shared().terminate(self)
			}
		}
	}

	@IBAction func adoptVisionTypeSetting(_ sender: NSMenuItem) {
		visionType = sender.tag
	}

	override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.action! {
		case #selector(adoptVisionTypeSetting(_:)):
			menuItem.state = visionType == menuItem.tag ? NSOnState : NSOffState
			return true
		default:
			return false
		}
	}

}
