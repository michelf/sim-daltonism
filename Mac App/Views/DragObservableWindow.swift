
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

/// A window that post notifications when to signal the start and end of the window being dragged.
class DragObservableWindow: NSPanel {
	
	static let willStartDragging = Notification.Name("WindowWillStartDraggingNotification")
	static let didEndDragging = Notification.Name("WindowDidEndDraggingNotification")

	var dragging = false
	var pausedDragTimer: Timer?

	override func mouseDragged(with event: NSEvent) {
		if !dragging {
			dragging = true
			NotificationCenter.default.post(name: DragObservableWindow.willStartDragging, object: self)
		}
		pausedDragTimer?.invalidate()
		pausedDragTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(stoppedDragging), userInfo: nil, repeats: true)
		super.mouseDragged(with: event)
	}

	@objc private func stoppedDragging() {
		// wait until mouse is up
		let leftMouseButtonMask = (1 << 0)
		guard (NSEvent.pressedMouseButtons & leftMouseButtonMask) == 0 else { return }

		pausedDragTimer?.invalidate()
		pausedDragTimer = nil
		dragging = false
		NotificationCenter.default.post(name: DragObservableWindow.didEndDragging, object: self)
	}

	override func orderOut(_ sender: Any?) {
		super.orderOut(sender)
		close()
	}

}
