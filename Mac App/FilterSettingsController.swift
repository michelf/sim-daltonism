
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

/// A controller for the buttons in the title bar controlling the various filter settings.
class FilterSettingsController: NSTitlebarAccessoryViewController {

	@IBOutlet var visionButton: NSButton!
	@IBOutlet var toolsButton: NSButton!
	@IBOutlet var refreshSpeedButton: NSButton!
	@IBOutlet var viewAreaButton: NSButton!

	override func viewDidLoad() {
		super.viewDidLoad()
		refreshSpeedButton.isHidden = true
	}

	@objc func refresh() {
		refreshSpeedButton.image = refreshSpeedDefault.image
		viewAreaButton.image = viewAreaDefault.image
	}

}

extension RefreshSpeed {
	fileprivate var image: NSImage {
		switch self {
		case .slow: return NSImage(named: "SlowFrameRateTemplate")!
		case .normal: return NSImage(named: "NormalFrameRateTemplate")!
		case .fast: return NSImage(named: "FastFrameRateTemplate")!
		}
	}
}

extension ViewArea {
	fileprivate var image: NSImage {
		switch self {
		case .underWindow: return NSImage(named: "FilteredTransparencyTemplate")!
		case .mousePointer: return NSImage(named: "FilteredMouseAreaTemplate")!
		}
	}
}

extension FilterSettingsController: NSToolbarDelegate {

	func makeToolbar() -> NSToolbar {
		let toolbar = NSToolbar()
		toolbar.delegate = self
		return toolbar
	}

	private static let visionItemIdentifier = NSToolbarItem.Identifier("vision")
	private static let toolsItemIdentifier = NSToolbarItem.Identifier("tools")
	private static let refreshSpeedItemIdentifier = NSToolbarItem.Identifier("refreshSpeed")
	private static let viewAreaItemIdentifier = NSToolbarItem.Identifier("viewArea")

	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [
			Self.visionItemIdentifier,
			Self.toolsItemIdentifier,
//			Self.refreshSpeedItemIdentifier,
//			.space,
			Self.viewAreaItemIdentifier,
		]
	}
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [
			Self.visionItemIdentifier,
			Self.toolsItemIdentifier,
			Self.refreshSpeedItemIdentifier,
			Self.viewAreaItemIdentifier,
			.space,
			.flexibleSpace,
		]
	}

	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		_ = view // equivalent to loadViewIfNeeded()

		func item(for button: NSButton) -> NSToolbarItem {
			let item = NSToolbarItem(itemIdentifier: itemIdentifier)
			item.view = button
			item.label = button.toolTip ?? ""
			button.heightAnchor.constraint(equalToConstant: 28).isActive = true

			let menuForm = NSMenuItem()
			menuForm.image = button.image
			menuForm.title = button.toolTip ?? ""
			menuForm.submenu = button.menu
			item.menuFormRepresentation = menuForm

			return item
		}

		switch itemIdentifier {
		case Self.visionItemIdentifier:
			return item(for: visionButton)
		case Self.toolsItemIdentifier:
			return item(for: toolsButton)
		case Self.refreshSpeedItemIdentifier:
			return item(for: refreshSpeedButton)
		case Self.viewAreaItemIdentifier:
			return item(for: viewAreaButton)
		case .flexibleSpace, .space:
			return NSToolbarItem(itemIdentifier: itemIdentifier)
		default:
			return nil
		}
	}

}
