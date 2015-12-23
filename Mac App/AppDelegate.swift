
//	Copyright 2015 Michel Fortin
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

enum RefreshSpeed: Int {
	case Slow = -1
	case Normal = 0
	case Fast = 1

	var image: NSImage {
		switch self {
		case .Slow: return NSImage(named: "SlowFrameRateTemplate")!
		case .Normal: return NSImage(named: "NormalFrameRateTemplate")!
		case .Fast: return NSImage(named: "FastFrameRateTemplate")!
		}
	}

	var updateInterval: NSTimeInterval {
		switch self {
		case .Slow:   return 0.1
		case .Normal: return 0.05
		case .Fast:   return 0.02
		}
	}
}

enum ViewArea: Int {
	case UnderWindow = 0
	case MousePointer = 1

	var image: NSImage {
		switch self {
		case .UnderWindow: return NSImage(named: "FilteredTransparencyTemplate")!
		case .MousePointer: return NSImage(named: "FilteredMouseAreaTemplate")!
		}
	}
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	@IBOutlet var filterWindowController: NSWindowController!
	@IBOutlet var aboutItem: NSMenuItem!

	func applicationWillFinishLaunching(notification: NSNotification) {
		SimDaltonismFilter.registerDefaults()
	}

	@IBAction func adoptSpeedSetting(sender: NSMenuItem) {
		guard let speed = RefreshSpeed(rawValue: sender.tag) else { return }
		NSUserDefaults.standardUserDefaults().setInteger(speed.rawValue, forKey: "RefreshSpeed")
	}

	@IBAction func adoptViewAreaSetting(sender: NSMenuItem) {
		guard let area = ViewArea(rawValue: sender.tag) else { return }
		NSUserDefaults.standardUserDefaults().setInteger(area.rawValue, forKey: "ViewArea")
	}

	override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
		switch menuItem.action {
		case "adoptSpeedSetting:":
			let current = NSUserDefaults.standardUserDefaults().integerForKey("RefreshSpeed")
			menuItem.state = current == menuItem.tag ? NSOnState : NSOffState
			return true
		case "adoptViewAreaSetting:":
			let current = NSUserDefaults.standardUserDefaults().integerForKey("ViewArea")
			menuItem.state = current == menuItem.tag ? NSOnState : NSOffState
			return true
		default:
			return false
		}
	}

}

