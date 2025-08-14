
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

@main
class AppDelegate: NSObject, NSApplicationDelegate {

	@IBOutlet var filterWindowController: NSWindowController!
	@IBOutlet var aboutItem: NSMenuItem!

	func applicationWillFinishLaunching(_ notification: Notification) {

	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		FilterWindowManager.shared.showFirstWindow()
	}

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		if !flag {
			FilterWindowManager.shared.showFirstWindow()
		}
		return false
	}

	@IBAction func createNewFilterWindow(_ sender: Any) {
		FilterWindowManager.shared.createNewWindow().showWindow(nil)
	}

	@IBAction func adoptSpeedSetting(_ sender: NSMenuItem) {
		guard let speed = RefreshSpeed(rawValue: sender.tag) else { return }
		refreshSpeedDefault = speed
	}


	@objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.action! {
		case #selector(adoptSpeedSetting(_:)):
			menuItem.state = refreshSpeedDefault.rawValue == menuItem.tag ? .on : .off
			return true
		case #selector(rateApp):
			// Only show this item when the app is comming from the App Store
			// by checking for the presence of a receipt.
			if let url = Bundle.main.appStoreReceiptURL,
			   FileManager.default.fileExists(atPath: url.path) {
				menuItem.isHidden = false
				return false
			} else {
				menuItem.isHidden = true
				return true
			}
		default:
			return self.responds(to: menuItem.action)
		}
	}

	@IBAction func sendFeedback(_ sender: AnyObject) {
		let mailtoURL = URL(string: "mailto:" + NSLocalizedString("sim-daltonism@michelf.ca", tableName: "URLs", comment: "Sim Daltonism feedback email"))!
		NSWorkspace.shared.open(mailtoURL)
	}

	@IBAction func openWebsite(_ sender: AnyObject) {
		let websiteURL = URL(string: NSLocalizedString("https://michelf.ca/projects/sim-daltonism/", tableName: "URLs", comment: "Sim Daltonism website URL"))!
		NSWorkspace.shared.open(websiteURL)
	}

	@IBAction func rateApp(_ sender: AnyObject) {
		let appStoreReviewURL = URL(string: "https://apps.apple.com/ca/app/sim-daltonism/id693112260?ls=1&mt=8&action=write-review")!
		NSWorkspace.shared.open(appStoreReviewURL)
	}

	@IBAction func openSourceWebsite(_ sender: AnyObject) {
		let githubURL = URL(string: "https://michelf.ca/open-source/sim-daltonism")!
		NSWorkspace.shared.open(githubURL)
	}

}

