
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

import Cocoa

/// Button with a rollover effect to be put in the filter window frame.
class MenuButton : NSButton {

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		self.isBordered = true
		if #available(macOS 11, *) {
		} else {
			alphaValue = 0.7
		}
	}

	override func awakeFromNib() {
		let trackingArea = NSTrackingArea(rect: self.bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeAlways], owner: self, userInfo: nil)
		addTrackingArea(trackingArea)
	}

	override func mouseEntered(with theEvent: NSEvent) {
		if #available(macOS 11, *) {
		} else {
			alphaValue = 1.0
		}
		super.mouseEntered(with: theEvent)
	}
	override func mouseExited(with theEvent: NSEvent) {
		if #available(macOS 11, *) {
		} else {
			alphaValue = 0.7
		}
		super.mouseExited(with: theEvent)
	}

	override func mouseDown(with theEvent: NSEvent) {
		let bounds = self.bounds
		guard bounds.contains(convert(theEvent.locationInWindow, from: nil)) else {
			return super.mouseDown(with: theEvent)
		}

		if let menu = self.menu {
			let location = NSPoint(x: bounds.minX - 16, y: bounds.maxY + 3)
			menu.font = NSFont.systemFont(ofSize: 12)
			menu.popUp(positioning: nil, at: location, in: self)
		}
	}

	override func mouseDragged(with event: NSEvent) {
		// Don't propagate dragging in button to window.
		//
		// This is triggered when the button is clicked with some
		// movement when dismissing a menu, and when it reaches the
		// window it causes the dragging veil to activate even though
		// dragging is disabled becase it comes from a button.
	}

}
