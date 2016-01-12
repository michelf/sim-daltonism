
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

class AboutBoxBackground: NSView {
	override var opaque: Bool { return true }
	override var mouseDownCanMoveWindow: Bool { return true }
	override func drawRect(dirtyRect: NSRect) {
		let rect = bounds
		let gradient = NSGradient(startingColor: NSColor.whiteColor(), endingColor: NSColor(calibratedWhite: 0.9, alpha: 1.0))
		gradient?.drawFromPoint(NSPoint(x: 0, y: rect.maxY), toPoint: NSPoint(x: 0, y: rect.minY), options: 0)
	}
}

class AboutBoxIconView: NSImageView {
	override var mouseDownCanMoveWindow: Bool { return true }
}

class AboutBoxScrollView: NSScrollView {
	override var scrollerStyle: NSScrollerStyle {
		get { return super.scrollerStyle }
		set {
			// Fix for an issue where the view offset is changed when setting scroller style
			let point = contentView.bounds.origin
			super.scrollerStyle = newValue
			documentView?.scrollPoint(point)
		}
	}
}

extension NSApplication {

	@IBAction func orderFrontAboutBox(sender: AnyObject) {
		AboutBoxController.sharedAboutBoxController.showWindow(sender)
	}

}

class AboutBoxController: NSWindowController {

	static var sharedAboutBoxController = AboutBoxController()

	@IBOutlet var iconView: NSImageView!
	@IBOutlet var textView: NSTextView!

	@NSCopying private var templateText: NSAttributedString? {
		didSet { updateText() }
	}

	override var windowNibName: String {
		return "AboutBox"
	}

	override func windowDidLoad() {
		window!.styleMask |= NSFullSizeContentViewWindowMask
		window!.titlebarAppearsTransparent = true
		window!.movableByWindowBackground = true

		templateText = textView.attributedString()

		// Adjust scroll view rect to fill superview bounds, but apply margins
		// to text container to preserve the rectangle for visible text
		var inset = textView.textContainerInset
		var frame = textView.enclosingScrollView!.frame
		let bounds = window!.contentView!.bounds
		let addedWidth = bounds.size.width - frame.maxX
		let addedHeight = bounds.size.height - frame.maxY
		inset.width += addedWidth
		inset.height += addedHeight
		frame.insetInPlace(dx: -addedWidth, dy: 0)
		frame.size.height = bounds.size.height
		frame.origin.y = bounds.origin.y
		textView.enclosingScrollView!.frame = frame
		textView.textContainerInset = inset
		textView.scrollToBeginningOfDocument(nil)

		super.windowDidLoad()
	}

	func updateText() {
		textView.textStorage?.setAttributedString(standardTextContent)
	}

	var appName: String {
		let mainBundle = NSBundle.mainBundle()
		if let name = mainBundle.objectForInfoDictionaryKey(kCFBundleNameKey as String) as? String {
			return name
		} else {
			return mainBundle.bundleURL.lastPathComponent!
		}
	}

	var appVersionWithBuildNumber: String {
		let mainBundle = NSBundle.mainBundle()
		let version = mainBundle.objectForInfoDictionaryKey("CFBundleShortVersionString") as? String ?? "?"
		let build = mainBundle.objectForInfoDictionaryKey(kCFBundleVersionKey as String) as? String

		if let build = build where build != version {
			return "\(version) (\(build))"
		} else {
			return version
		}
	}

	var appVersion: String {
		return "Version \(appVersionWithBuildNumber)"
	}

	var appCopyright: String {
		return NSBundle.mainBundle().objectForInfoDictionaryKey("NSHumanReadableCopyright") as? String ?? ""
	}

	var appCredits: NSAttributedString {
		for ext in ["html", "rtf", "rtfd"] {
			if let creditsURL = NSBundle.mainBundle().URLForResource("Credits", withExtension: ext),
			   let credits = NSAttributedString(URL: creditsURL, documentAttributes: nil) {
				return credits
			}
		}
		return NSAttributedString() // credits not found
	}

	var standardTextContent: NSAttributedString {
		guard let templateText = self.templateText else { return NSAttributedString() }

		let textString = templateText.string as NSString
		let appRange = textString.rangeOfString("App")
		let versionRange = textString.rangeOfString("Version")
		let copyrightRange = textString.rangeOfString("Copyright")
		let creditsRange = textString.rangeOfString("Credits")

		let finalText = templateText.mutableCopy() as! NSMutableAttributedString

		// Replace from last to first so ranges stay valid after each replacement
		finalText.replaceCharactersInRange(creditsRange, withAttributedString: appCredits)
		finalText.replaceCharactersInRange(copyrightRange, withString: appCopyright)
		finalText.replaceCharactersInRange(versionRange, withString: appVersion)
		finalText.replaceCharactersInRange(appRange, withString: appName)

		return finalText
	}

	override func showWindow(sender: AnyObject?) {
		if !window!.visible {
			textView.scrollPoint(NSZeroPoint)
			window!.center()
		}
		super.showWindow(sender)

		textView.enclosingScrollView?.flashScrollers()
	}

}
