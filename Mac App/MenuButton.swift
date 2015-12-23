
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

class MenuButton : NSButton {

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		alphaValue = 0.7
	}

	override func awakeFromNib() {
		let trackingArea = NSTrackingArea(rect: self.bounds, options: [.MouseEnteredAndExited, .ActiveAlways], owner: self, userInfo: nil)
		addTrackingArea(trackingArea)
	}

	override func mouseEntered(theEvent: NSEvent) {
		alphaValue = 1.0
		super.mouseEntered(theEvent)
	}
	override func mouseExited(theEvent: NSEvent) {
		alphaValue = 0.7
		super.mouseExited(theEvent)
	}

	override func mouseDown(theEvent: NSEvent) {
		let bounds = self.bounds
		guard bounds.contains(convertPoint(theEvent.locationInWindow, fromView: nil)) else {
			return super.mouseDown(theEvent)
		}

		if let menu = self.menu {
			let location = NSPoint(x: bounds.minX - 16, y: bounds.maxY + 3)
			menu.font = NSFont.systemFontOfSize(12)
			menu.popUpMenuPositioningItem(nil, atLocation: location, inView: self)
		}
	}
	override func mouseUp(theEvent: NSEvent) {
	}

}