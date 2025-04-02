
//    Copyright 2005-2021 Michel Fortin
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

import Cocoa

/// An object that manages filter windows.
class FilterWindowManager: NSObject, NSWindowRestoration {

	static let shared = FilterWindowManager()

	private override init() {}

	/// Set of all the registered filter windows.
	/// - Note: Someone need to retain the window controllers if we want the
	/// windows to stay on screen. This is what we do here.
	private(set) var windowControllers: Set<FilterWindowController> = []

	/// Instantiate a new filter window controller and return it. The window 
	/// is not visible yet. Call `showWindow` on the returned controller.
	func createNewWindow() -> FilterWindowController {
		let controller = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "FilterWindow") as! FilterWindowController
		positionNewWindow(for: controller)
		return controller
	}

	/// Create a new filter window and make it visible, but only if there is 
	/// currently no other filter window.
	@discardableResult
	func showFirstWindow() -> FilterWindowController? {
		if windowControllers.isEmpty {
			let controller = createNewWindow()
			positionNewWindow(for: controller)
			controller.showWindow(nil)
			return controller
		} else {
			return nil
		}
	}

	/// Register the controller of a filter window. The controller is retained
	/// (so the window doesn't disappear) and added to the Window menu.
	func addWindowController(_ controller: FilterWindowController) {
		windowControllers.insert(controller)
		if let window = controller.window {
			NSApp.addWindowsItem(window, title: window.title, filename: false)
		}
	}
	/// Update the listing of this window controller in the Window menu.
	func changedWindowController(_ controller: FilterWindowController) {
		if let window = controller.window {
			NSApp.changeWindowsItem(window, title: window.title, filename: false)
		}
	}
	/// Unregister the controller of a filter window. The controller is released
	/// and removed from the Window menu.
	func removeWindowController(_ controller: FilterWindowController) {
		if let window = controller.window {
			NSApp.removeWindowsItem(window)
		}
		windowControllers.remove(controller)
		if windowControllers.isEmpty {
			controller.window?.saveFrame(usingName: "FilterWindow")
			controller.setVisionTypeDefault() // so next created window will follow those defaults
		}
	}

	/// Position new window by copying frame from the filter window that is key
	/// (if applicable) or from the default filter window location saved in the
	/// user defaults.
	private func positionNewWindow(for controller: FilterWindowController) {
		guard controller.window?.isVisible == false else { return }
		if let current = NSApp.keyWindow?.windowController as? FilterWindowController, windowControllers.contains(current), let frame = current.window?.frame {
			controller.window?.setFrame(frame, display: false)
		} else {
			controller.window?.setFrameUsingName("FilterWindow")
		}
		controller.cascade()
	}

	/// Restore a window in the state it was left. Implements NSWindowRestoration
	class func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
		let controller = shared.createNewWindow()
		controller.window?.restoreState(with: state)
		controller.window?.identifier = identifier
		DispatchQueue.main.async {
			completionHandler(controller.window, nil)
		}
		shared.addWindowController(controller)
	}

}
