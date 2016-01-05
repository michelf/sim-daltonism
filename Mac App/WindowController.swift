
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

class WindowController: NSWindowController, NSWindowDelegate {

    override func windowDidLoad() {
        super.windowDidLoad()
    
		// cannot set from IB:
		// Note: window level is set to 1 above Red Stripe's window level
		// so you can use the two together.
		window?.level = Int(CGWindowLevelForKey(CGWindowLevelKey.AssistiveTechHighWindowLevelKey) + 1)
		window?.hidesOnDeactivate = false
		window?.standardWindowButton(.ZoomButton)?.enabled = false
		window?.movable = false

		//window?.titleVisibility = .Hidden
		let accessory = NSStoryboard(name: "Main", bundle: nil).instantiateControllerWithIdentifier("WindowControls") as! NSTitlebarAccessoryViewController
		accessory.layoutAttribute = .Right
		window?.addTitlebarAccessoryViewController(accessory)
    }

	func windowWillClose(notification: NSNotification) {
		// quit app when window closes
		dispatch_async(dispatch_get_main_queue()) {
			NSApplication.sharedApplication().terminate(self)
		}
	}

}
