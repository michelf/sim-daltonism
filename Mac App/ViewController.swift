
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

class ViewController: NSViewController {

	var filteredView: FilteredView {
		return view as! FilteredView
	}

	@IBAction func adoptVisionTypeSetting(sender: NSMenuItem) {
		let visionType = sender.tag
		NSUserDefaults.standardUserDefaults().setInteger(visionType, forKey: SimVisionTypeKey)
	}

	override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
		switch menuItem.action {
		case "adoptVisionTypeSetting:":
			let current = NSUserDefaults.standardUserDefaults().integerForKey(SimVisionTypeKey)
			menuItem.state = current == menuItem.tag ? NSOnState : NSOffState
			return true
		default:
			return false
		}
	}

}