
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
	private var window: NSWindow? { view?.window } // Parent window to read geometry

	// Gating and capture frequency
	private var refreshSpeed: RefreshSpeed = .normal {
		didSet { reconfigureStream() }
	}
	private var framesSinceLastCapture = 0
	private var stream: SCStream?

	private let legalWindowNumbers = (0...Int(CGWindowID.max))
	private var isResizingOrMoving: Bool = false { didSet { disableOrRestartCaptureAfterWindowInteraction() } }
	private var isOccluded: Bool = false { didSet { disableOrRestartCaptureAfterWindowInteraction() } }
	private var capturingDisabled = false
	private var unhideOnNextDisplay = false

	// Current capture
	private var preferredCaptureArea = ViewArea.underWindow {
		didSet { reconfigureStream() }
	}
	private var isCapturing = false {
		didSet { reconfigureStream() }
	}


	public init(view: FilteredMetalView) {
		self.view = view
		super.init()
		view.viewUpdatesSubscriber = self
		updateFromDefaults()

		setupStream()

		NotificationCenter.default.addObserver(self, selector: #selector(invalidateStreamFilter), name: NSApplication.didBecomeActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(invalidateStreamFilter), name: NSApplication.didResignActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(invalidateStreamFilter), name: NSApplication.didChangeScreenParametersNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(invalidateStreamFilter), name: NSWindow.didBecomeKeyNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(invalidateStreamFilter), name: NSWindow.didBecomeMainNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(invalidateStreamFilter), name: NSWindow.didChangeScreenNotification, object: nil)
	}

	func setupStream() {
		assert(Thread.isMainThread)
		getContentFilter { [weak self] filter in
			guard let filter, let self else { return }
			stream = SCStream(filter: filter, configuration: configuration(), delegate: self)
			streamFilter = filter
			do {
				try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: nil)
			} catch {
				NSLog("\(#function) addStreamOutput error \(error)")
			}
			disableOrRestartCaptureAfterWindowInteraction()
		}
	}

	func configuration() -> SCStreamConfiguration {
		assert(Thread.isMainThread)
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
		switch refreshSpeed {
		case .slow:
			config.minimumFrameInterval = CMTime(value: 1, timescale: 12)
		case .normal:
			config.minimumFrameInterval = CMTime(value: 1, timescale: 24)
		case .fast:
			config.minimumFrameInterval = .zero
		}
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

	func getContentFilter(completion: @escaping (SCContentFilter?) -> ()) {
		assert(Thread.isMainThread)
		guard let thisWindowID = window?.windowID,
			  let thisScreenID = window?.screen?.directDisplayID
		else {
			completion(nil)
			return
		}

		SCShareableContent.getWithCompletionHandler { content, error in
			guard let content else {
				NSLog("\(#function) no content \(error?.localizedDescription ?? "<no error provided>")")
				completion(nil)
				return
			}
			guard let thisDisplay = content.displays.first(where: { $0.displayID == thisScreenID }) else {
				NSLog("\(#function) display not found in content")
				completion(nil)
				return
			}
			let thisWindow = content.windows.first(where: { $0.windowID == thisWindowID })
			guard let thisWindow else {
				let filter = SCContentFilter(display: thisDisplay, excludingWindows: [])
				DispatchQueue.main.async {
					completion(filter)
				}
				return
			}
			SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnlyAbove: thisWindow) { contentBelow, error in
				let excludedWindows = [thisWindow] + (contentBelow?.windows ?? [])
				let filter = SCContentFilter(display: thisDisplay, excludingWindows: excludedWindows)
				DispatchQueue.main.async {
					completion(filter)
				}
			}
		}
	}

	var streamNeedsReconfiguration = false
	var streamWaitingFirstFrameAfterReconfiguration = true
	var streamReconfigurationTimer: Timer?
	var streamFilter: SCContentFilter?

	@objc func invalidateStreamFilter() {
		getContentFilter { [weak self] filter in
			guard let filter, let self else { return }
			guard streamFilter != filter else {
				return // no change
			}
			streamFilter = filter
			stream?.updateContentFilter(filter)
		}
	}

	@objc func reconfigureStream() {
		assert(Thread.isMainThread)
		stream?.updateConfiguration(configuration())
		streamNeedsReconfiguration = false
		streamWaitingFirstFrameAfterReconfiguration = true
		streamReconfigurationTimer?.invalidate()
		streamReconfigurationTimer = nil
	}

	@objc func invalidateStreamConfiguration() {
		if streamWaitingFirstFrameAfterReconfiguration {
			streamNeedsReconfiguration = true
			streamReconfigurationTimer = Timer.scheduledTimer(withTimeInterval: 1/60.0, repeats: false) { [weak self] timer in
				self?.reconfigureStream()
			}
		} else {
			reconfigureStream()
		}
	}

	public func checkCapturePermission() -> Bool {
		let permissionGranted = CGPreflightScreenCaptureAccess()
		if !permissionGranted {
			CGRequestScreenCaptureAccess()
		}
		return permissionGranted
	}


	// MARK: - Mouse Tracking

	public func handleMouseEvent(_ event: NSEvent) {
		invalidateStreamConfiguration()
	}

	deinit {
		stopSession()
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

		center.addObserver(self, selector: #selector(reconfigureStream),
						   name: NSWindow.didMoveNotification,
						   object: window)

		center.addObserver(self, selector: #selector(reconfigureStream),
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

		afterCapturing()
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

	private func afterCapturing() {
		guard unhideOnNextDisplay || streamNeedsReconfiguration else { return }
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			// recheck, because the state could have changed since the dispatch
			if unhideOnNextDisplay == true {
				unhideOnNextDisplay = false
				view?.isHidden = false
			}
			if streamWaitingFirstFrameAfterReconfiguration {
				streamWaitingFirstFrameAfterReconfiguration = false
			}
			if streamNeedsReconfiguration {
				reconfigureStream()
			}
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

#if os(macOS)
extension NSScreen {

	var directDisplayID: CGDirectDisplayID? {
		deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
	}

}
extension NSWindow {

	var windowID: CGWindowID {
		CGWindowID(windowNumber)
	}

}
#endif
