
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

import AppKit
import ScreenCaptureKit

@available(macOS 12.3, *)
public class ScreenCaptureStreamSCKit: NSObject, SCStreamDelegate {

	public weak var delegate: ScreenCaptureStreamDelegate? = nil // Recipient of captured CIImages
	private weak var view: FilteredMetalView? = nil // Rendering view to read geometry
	private weak var window: NSWindow? = nil // Parent window to read geometry

	// Gating and capture frequency
	private var refreshSpeed: RefreshSpeed = .normal
	private var framesSinceLastCapture = 0
	private var stream: SCStream?

	private let legalWindowNumbers = (0...Int(CGWindowID.max))
	private var isResizingOrMoving: Bool = false { didSet { disableOrRestartCaptureAfterWindowInteraction() } }
	private var isOccluded: Bool = false { didSet { disableOrRestartCaptureAfterWindowInteraction() } }
	private var capturingDisabled = false
	private var unhideOnNextDisplay = false

	// Current capture
	private var preferredCaptureArea = ViewArea.underWindow
	private weak var queue: DispatchQueue?
	private var isCapturing = false


	public init(view: FilteredMetalView, window: NSWindow, queue: DispatchQueue) {
		self.window = window
		self.view = view
		self.queue = queue
		super.init()
		view.viewUpdatesSubscriber = self
		updateFromDefaults()
		checkRecordingPermissions()

		SCShareableContent.getWithCompletionHandler { [weak self] content, error in
			DispatchQueue.main.async { [weak self] in
				self?.setupStream(with: content, error: error)
			}
		}
	}

	func setupStream(with content: SCShareableContent?, error: Error?) {
		guard let content else {
			if let error {
				NSLog("\(#function) \(error)")
			} else {
				NSLog("\(#function) no content")
			}
			return
		}

		let filter = contentFilter(for: content)
		let config = configuration()

		stream = SCStream(filter: filter, configuration: config, delegate: self)
		do {
			try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
		} catch {
			NSLog("\(#function) addStreamOutput error \(error)")
		}
		disableOrRestartCaptureAfterWindowInteraction()
	}

	func configuration() -> SCStreamConfiguration {
		let config = SCStreamConfiguration()

		let screenFrame = window?.screen?.frame ?? CGDisplayBounds(CGMainDisplayID())
		var captureRect = getPreferredViewAreaInScreenCoordinates()
		captureRect.origin.x -= screenFrame.origin.x
		captureRect.origin.y -= screenFrame.origin.y
		captureRect.origin.y = screenFrame.height - captureRect.origin.y - captureRect.height

		let scaleFactor = view?.window?.backingScaleFactor ?? 1

		config.width = Int(captureRect.size.width * scaleFactor)
		config.height = Int(captureRect.size.height * scaleFactor)
		config.scalesToFit = false
		config.sourceRect = captureRect
		config.minimumFrameInterval = .zero
		config.showsCursor = false
		if #available(macOS 14.0, *) {
			config.captureResolution = .automatic
		}
		if #available(macOS 15.0, *) {
			config.showMouseClicks = true
		}
		config.queueDepth = 2

		if #available(macOS 14.0, *) {
			config.shouldBeOpaque = true
			config.ignoreGlobalClipDisplay = true
			config.presenterOverlayPrivacyAlertSetting = .always
		}
		return config
	}

	func contentFilter(for content: SCShareableContent) -> SCContentFilter {
		let displayID = window?.screen?.directDisplayID
		let display = content.displays.first {
			$0.displayID == displayID
		}

		let windowID = window.map { CGWindowID($0.windowNumber) }
		let currentWindow = content.windows.first {
			$0.windowID == windowID
		}

		let filter = SCContentFilter(display: display!, excludingWindows: [currentWindow].compactMap { $0 })
		return filter
	}

	@objc func updateStreamConfiguration() {
		stream?.updateConfiguration(configuration())
	}

	func checkRecordingPermissions() {
		if #available(macOS 10.15, *) {
			let permissionGranted = CGPreflightScreenCaptureAccess()
			if !permissionGranted {
				presentScreenCaptureAlert()
				CGRequestScreenCaptureAccess()
			}
		} else {
			// Permissions handling is for 10.15+
		}
	}

}

// MARK: - Setup

@available(macOS 12.3, *)
extension ScreenCaptureStreamSCKit: ScreenCaptureStream {

	public func stopSession() {
		NotificationCenter.default.removeObserver(self)
		stream?.stopCapture()
	}

	public func startSession(in frame: NSRect, delegate: ScreenCaptureStreamDelegate) throws {
		self.delegate = delegate
		monitorUserPreferences()
		guard let window = window else { return }
		setupMonitorsForInteraction(with: window)
		disableOrRestartCaptureAfterWindowInteraction()
	}

}

@available(macOS 12.3, *)
private extension ScreenCaptureStreamSCKit {

	func monitorUserPreferences() {
		NotificationCenter.default.addObserver(self, selector: #selector(updateFromDefaults),
											   name: UserDefaults.didChangeNotification,
											   object: nil)
	}

	func setupMonitorsForInteraction(with window: NSWindow) {
		let center = NotificationCenter.default

		center.addObserver(self, selector: #selector(updateStreamConfiguration),
						   name: NSWindow.didMoveNotification,
						   object: window)

		center.addObserver(self, selector: #selector(updateStreamConfiguration),
						   name: NSWindow.didResizeNotification,
						   object: window)

		center.addObserver(self, selector: #selector(markAsMoving),
						   name: Window.willStartDragging,
						   object: window)

		center.addObserver(self, selector: #selector(markAsStationary),
						   name: Window.didEndDragging,
						   object: window)

		center.addObserver(self, selector: #selector(windowDidChangeOcclusionState),
						   name: NSWindow.didChangeOcclusionStateNotification,
						   object: window)
	}

	@objc func markAsMoving() {
		isResizingOrMoving = true
	}

	@objc func markAsStationary() {
		isResizingOrMoving = false
	}

	@objc func windowDidChangeOcclusionState(_ notification: Notification) {
		let windowIsVisible = window?.occlusionState.contains(.visible) == true
		isOccluded = !windowIsVisible
	}
}


// MARK: - Capture

@available(macOS 12.3, *)
extension ScreenCaptureStreamSCKit: SCStreamOutput {

	public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
		guard type == .screen,
			  let pixelBuffer = sampleBuffer.imageBuffer,
			  let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
		else {
			return
		}
		let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)

		delegate?.didCaptureFrame(image: CIImage(ioSurface: surface))

		afterCapturingUnhideOnNextDisplayIfNeeded()
	}

//	func captureWindowsBelow(_ captureRect: CGRect, windowID: CGWindowID, backingScaleFactor: CGFloat) {
//		defer { isCapturing = false }
//		guard !capturingDisabled else { return }
//
//		guard let captureImage = CGWindowListCreateImage(captureRect,.optionOnScreenBelowWindow, windowID, [])
//		else { return }
//
//		guard !capturingDisabled else { return }
//
//		delegate?.didCaptureFrame(image: CIImage(cgImage: captureImage))
//
//		afterCapturingUnhideOnNextDisplayIfNeeded()
//	}

	private func afterCapturingUnhideOnNextDisplayIfNeeded() {
		guard unhideOnNextDisplay else { return }
		DispatchQueue.main.async { [weak self] in
			// recheck, because the state could have changed since the dispatch
			guard self?.unhideOnNextDisplay == true else { return }
			self?.unhideOnNextDisplay = false
			self?.view?.isHidden = false
		}
	}
}

// MARK: - Schedule/Prepare Capture

import CoreVideo

@available(macOS 12.3, *)
private extension ScreenCaptureStreamSCKit {

//	@objc func captureImmediately() {
//		prepareFrameCapture()
//	}

//	func prepareFrameCapture() {
//		guard let window = window else { return }
//		guard legalWindowNumbers.contains(window.windowNumber) else {
//			NSLog("Skipping capture for uninitialized window ID \(window.windowNumber).");
//			return
//		}
//
//		let canCapture = !isCapturing && !capturingDisabled
//		guard canCapture else { return }
//		isCapturing = true
//
//		let windowID = CGWindowID(window.windowNumber)
//		let viewScaleFactor = window.backingScaleFactor
//
//
//		let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
//		var captureRect = getPreferredViewAreaInScreenCoordinates()
//		captureRect.origin.y = mainDisplayBounds.height - captureRect.origin.y - captureRect.height
//
////		queue?.async { [weak self] in
////			self?.captureWindowsBelow(captureRect, windowID: windowID, backingScaleFactor: viewScaleFactor)
////		}
//	}

}

// MARK: - Helpers to Schedule/Prepare Capture

@available(macOS 12.3, *)
private extension ScreenCaptureStreamSCKit {

	func getPreferredViewAreaInScreenCoordinates() -> CGRect {
		assert(Thread.isMainThread)
		guard let view = view, let window = window else { return .zero }
		let viewInWindow = view.convert(view.bounds, to: window.contentView)
		var viewInScreen = window.convertToScreen(viewInWindow)

		switch preferredCaptureArea {
		case .underWindow: return viewInScreen

		case .mousePointer:
			let mouseLocation = NSEvent.mouseLocation
			// if mouse is inside window, fall through .UnderWindow instead
			if !viewInScreen.contains(mouseLocation) {
				viewInScreen.origin = mouseLocation
				let mouseView = viewInScreen.offsetBy(dx: -round(viewInScreen.width/2),
													  dy: -round(viewInScreen.height/2))
				return mouseView
			}
			return viewInScreen
		}
	}

	func disableOrRestartCaptureAfterWindowInteraction() {
		let shouldDisable = isResizingOrMoving || isOccluded

		if shouldDisable {
			capturingDisabled = true
			view?.isHidden = true
			stream?.stopCapture()
		} else {
			stream?.startCapture()
			capturingDisabled = false
//			captureImmediately()
			unhideOnNextDisplay = true
		}
	}
}

@available(macOS 12.3, *)
extension ScreenCaptureStreamSCKit: ViewUpdatesSubscriber {

	public func viewWillStartLiveResize() {
		markAsMoving()
	}

	public func viewDidEndLiveResize() {
		markAsStationary()
	}

}

// MARK: - Apply User Preferences

@available(macOS 12.3, *)
private extension ScreenCaptureStreamSCKit {

	@objc func updateFromDefaults() {
		refreshSpeed = refreshSpeedDefault
		preferredCaptureArea = viewAreaDefault
	}
}

// MARK: - Permission Alert

@available(macOS 12.3, *)
private extension ScreenCaptureStreamSCKit {

	func presentScreenCaptureAlert() {
		guard let window = window else { return }

		let title = NSLocalizedString("AllowScreenRecording", tableName: "Alerts", comment: "")
		let explanation = NSLocalizedString("AllowScreenRecordingMessage", tableName: "Alerts", comment: "")
		let okButton = NSLocalizedString("OpenSystemPreferences", tableName: "Alerts", comment: "")
		let cancelButton = NSLocalizedString("FilterDesktopOnly", tableName: "Alerts", comment: "")
		let image = NSImage(named: NSImage.Name("ScreenCaptureAlert"))!
		let imageSize = CGSize(width: 450, height: 450)

		let alert = NSAlert()

		alert.messageText = title
		alert.informativeText = explanation
		alert.addButton(withTitle: okButton)
		alert.addButton(withTitle: cancelButton)

		let view = NSImageView(image: image)
		view.frame = CGRect(origin: .zero, size: imageSize)
		alert.accessoryView = view

		alert.beginSheetModal(for: window) { [weak self] response in
			switch response {
			case .alertSecondButtonReturn: return
				// Does nothing on "cancel".
				// The desktop will be shown and filtered, but no windows can be captured.

			default: self?.openPrivacyPanel()
			}
		}
	}

	func openPrivacyPanel() {
		let privacyPanel = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
		NSWorkspace.shared.open(privacyPanel)
	}
}

#if os(macOS)
extension NSScreen {

	var directDisplayID: CGDirectDisplayID? {
		deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
	}

}
#endif
