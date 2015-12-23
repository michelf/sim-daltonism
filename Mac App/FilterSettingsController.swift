
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

class FilterSettingsController: NSTitlebarAccessoryViewController {

	@IBOutlet var visionButton: NSButton!
	@IBOutlet var refreshSpeedButton: NSButton!
	@IBOutlet var viewAreaButton: NSButton!

	override func awakeFromNib() {
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "refresh", name: NSUserDefaultsDidChangeNotification, object: nil)
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	@objc func refresh() {
		let defaults = NSUserDefaults.standardUserDefaults()
		if let refreshSpeed = RefreshSpeed(rawValue: defaults.integerForKey("RefreshSpeed")) {
			refreshSpeedButton.image = refreshSpeed.image
		}
		if let viewArea = ViewArea(rawValue: defaults.integerForKey("ViewArea")) {
			viewAreaButton.image = viewArea.image
		}
	}

}