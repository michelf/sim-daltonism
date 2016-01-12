
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

let WindowWillStartDraggingNotification = "WindowWillStartDraggingNotification"
let WindowDidEndDraggingNotification = "WindowDidEndDraggingNotification"

class Window: NSPanel {

	var initialLocation = NSMakePoint(0, 0)
	var dragging = false

	override func mouseDown(theEvent: NSEvent) {
		initialLocation = theEvent.locationInWindow
		var tracking = true
		while tracking {
			let theEvent = nextEventMatchingMask(Int(NSEventMask.LeftMouseUpMask.union(.LeftMouseDraggedMask).rawValue))!
			switch theEvent.type {
				case .LeftMouseDragged:
					let windowFrame = frame
					var newOrigin = windowFrame.origin

					// Get the mouse location in window coordinates.
					let currentLocation = theEvent.locationInWindow
					// Update the origin with the diffeerence between the new mouse location and the old one
					newOrigin.x += currentLocation.x - initialLocation.x
					newOrigin.y += currentLocation.y - initialLocation.y

					if !dragging {
						dragging = true
						NSNotificationCenter.defaultCenter().postNotificationName(WindowWillStartDraggingNotification, object: self)
					}

					// Move window to the new location
					setFrameOrigin(newOrigin)

					break;

				case .LeftMouseUp:
					tracking = false
					break;
				default:
					/* Ignore any other kind of event. */
					break;
			}
		};
		
		if dragging {
			dragging = false
			NSNotificationCenter.defaultCenter().postNotificationName(WindowDidEndDraggingNotification, object: self)
		}
	}

	override func mouseUp(theEvent: NSEvent) {
		if dragging {
			dragging = false
			NSNotificationCenter.defaultCenter().postNotificationName(WindowDidEndDraggingNotification, object: self)
		}
		super.mouseUp(theEvent)
	}

}