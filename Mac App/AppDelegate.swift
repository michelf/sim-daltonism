
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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	@IBOutlet var filterWindowController: NSWindowController!
	@IBOutlet var aboutItem: NSMenuItem!

	func applicationWillFinishLaunching(notification: NSNotification) {
		SimDaltonismFilter.registerDefaults()
	}

	@IBAction func adoptSpeedSetting(sender: NSMenuItem) {
		guard let speed = RefreshSpeed(rawValue: sender.tag) else { return }
		refreshSpeedDefault = speed
	}

	@IBAction func adoptViewAreaSetting(sender: NSMenuItem) {
		guard let area = ViewArea(rawValue: sender.tag) else { return }
		viewAreaDefault = area
	}

	override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
		switch menuItem.action {
		case "adoptSpeedSetting:":
			menuItem.state = refreshSpeedDefault.rawValue == menuItem.tag ? NSOnState : NSOffState
			return true
		case "adoptViewAreaSetting:":
			menuItem.state = viewAreaDefault.rawValue == menuItem.tag ? NSOnState : NSOffState
			return true
		default:
			return self.respondsToSelector(menuItem.action)
		}
	}

	@IBAction func sendFeedback(sender: AnyObject) {
		let mailtoURL = NSURL(string: "mailto:sim-daltonism@michelf.ca")!
		NSWorkspace.sharedWorkspace().openURL(mailtoURL)
	}

}

