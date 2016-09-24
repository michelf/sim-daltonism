
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

class Window: NSPanel {
	
	static let willStartDragging = Notification.Name("WindowWillStartDraggingNotification")
	static let didEndDragging = Notification.Name("WindowDidEndDraggingNotification")

	var initialLocation = NSMakePoint(0, 0)
	var dragging = false

	override func mouseDown(with theEvent: NSEvent) {
		initialLocation = theEvent.locationInWindow
		var tracking = true
		while tracking {
			let theEvent = nextEvent(matching: NSEventMask(rawValue: NSEventMask.leftMouseUp.union(.leftMouseDragged).rawValue))!
			switch theEvent.type {
				case .leftMouseDragged:
					let windowFrame = frame
					var newOrigin = windowFrame.origin

					// Get the mouse location in window coordinates.
					let currentLocation = theEvent.locationInWindow
					// Update the origin with the diffeerence between the new mouse location and the old one
					newOrigin.x += currentLocation.x - initialLocation.x
					newOrigin.y += currentLocation.y - initialLocation.y

					if !dragging {
						dragging = true
						NotificationCenter.default.post(name: Window.willStartDragging, object: self)
					}

					// Move window to the new location
					setFrameOrigin(newOrigin)

					break;

				case .leftMouseUp:
					tracking = false
					break;
				default:
					/* Ignore any other kind of event. */
					break;
			}
		};
		
		if dragging {
			dragging = false
			NotificationCenter.default.post(name: Window.didEndDragging, object: self)
		} else if !theEvent.modifierFlags.contains(.command) {
			// make sure the app activates if when clicking on the title bar
			// without dragging.
			NSApp.activate(ignoringOtherApps: true)
		}
	}

	override func mouseUp(with theEvent: NSEvent) {
		if dragging {
			dragging = false
			NotificationCenter.default.post(name: Window.didEndDragging, object: self)
		}
		super.mouseUp(with: theEvent)
	}

	override func orderOut(_ sender: Any?) {
		super.orderOut(sender)
		close()
	}

}
