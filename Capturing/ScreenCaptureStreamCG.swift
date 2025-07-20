
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

@MainActor
public class ScreenCaptureStreamCG {

	private struct WeakDelegate: Sendable {
		weak var object: CaptureStreamDelegate?
	}
	private let _delegate = Mutex(WeakDelegate())
	/// Recipient of captured CIImages
	nonisolated public var delegate: CaptureStreamDelegate? {
		get { _delegate.withLock { $0.object } }
		set { _delegate.withLock { $0.object = newValue } }
	}
	/// Rendering view to read geometry
    private weak var view: FilteredMetalView? = nil
	// Parent window to read geometry
	private var window: NSWindow? { view?.window }

    // Gating and capture frequency
    private var refreshSpeed: RefreshSpeed = .normal
    private var framesSinceLastCapture = 0
	fileprivate let displayLink = DispatchQueueMutex<CVDisplayLink?>(nil, label: "")

    private let legalWindowNumbers = (0...Int(CGWindowID.max))
    private var isResizingOrMoving: Bool = false { didSet { disableOrRestartCaptureAfterWindowInteraction() } }
    private var isOccluded: Bool = false { didSet { disableOrRestartCaptureAfterWindowInteraction() } }

    // Current capture
	private struct CaptureState {
		var capturingDisabled = false
		var isCapturing = false
		var unhideOnNextDisplay = false
	}
    private var preferredCaptureArea = ViewArea.underWindow
	private let captureState = Mutex(CaptureState())
	private let captureQueue = DispatchQueue(label: nextDispatchQueueLabel(), qos: .userInitiated)

	@MainActor
    public init(view: FilteredMetalView) {
        self.view = view
        view.viewUpdatesSubscriber = self
        updateFromDefaults()
    }

    public func checkCapturePermission() -> Bool {
		guard #available(macOS 10.15, *) else {
			return true // no permission needed before 10.15
		}
		let permissionGranted = CGPreflightScreenCaptureAccess()
		if !permissionGranted {
			CGRequestScreenCaptureAccess()
		}
		return permissionGranted
    }

}

// MARK: - Setup

extension ScreenCaptureStreamCG: CaptureStream {

    public func stopSession() {
        NotificationCenter.default.removeObserver(self)
		displayLink.enqueue { displayLink in
			if let link = displayLink {
				CVDisplayLinkStop(link)
				displayLink = nil
			}
        }
    }

    public func startSession(in frame: NSRect, delegate: CaptureStreamDelegate) throws {
        self.delegate = delegate
        monitorUserPreferences()
        guard let window = window else { return }
        setupMonitorsForInteraction(with: window)
        createDisplayLink()
    }

	public func handleMouseEvent(_ event: NSEvent) {
		captureImmediately()
	}

}

private extension ScreenCaptureStreamCG {

    func monitorUserPreferences() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateFromDefaults),
                           name: UserDefaults.didChangeNotification,
                           object: nil)
    }

    func setupMonitorsForInteraction(with window: NSWindow) {
        let center = NotificationCenter.default

        center.addObserver(self, selector: #selector(captureImmediately),
                           name: NSWindow.didMoveNotification,
                           object: window)

        center.addObserver(self, selector: #selector(markAsMoving),
                           name: DragObservableWindow.willStartDragging,
                           object: window)

        center.addObserver(self, selector: #selector(markAsStationary),
                           name: DragObservableWindow.didEndDragging,
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

private extension ScreenCaptureStreamCG {

    func captureWindowsBelow(_ captureRect: CGRect, windowID: CGWindowID, backingScaleFactor: CGFloat) {
		captureQueue.async { [weak self] in
			guard let self else { return }
			let captureImage = captureState.withLock { captureState -> CGImage? in
				guard !captureState.capturingDisabled else { return nil }

				guard let captureImage = CGWindowListCreateImage(captureRect,.optionOnScreenBelowWindow, windowID, [])
				else { return nil }

				guard !captureState.capturingDisabled else { return nil }
				return captureImage
			}

			if let captureImage {
				self.delegate?.didCaptureFrame(image: CIImage(cgImage: captureImage))
				self.afterCapturingUnhideOnNextDisplayIfNeeded()
			}

			captureState.withLock { captureState in
				captureState.isCapturing = false
			}
		}
    }

    nonisolated func afterCapturingUnhideOnNextDisplayIfNeeded() {
		guard captureState.withLock({ $0.unhideOnNextDisplay }) else { return }
        DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			let unHide = captureState.withLock { captureState in
				defer { captureState.unhideOnNextDisplay = false }
				return captureState.unhideOnNextDisplay
			}
			if unHide == true {
				view?.isHidden = false
			}
        }
    }
}

// MARK: - Schedule/Prepare Capture

import CoreVideo

private extension ScreenCaptureStreamCG {

    private func createDisplayLink() {
        displayLink.enqueue { [weak self] displayLink in
			guard let self = self else { return }
			CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
            guard let displayLink = displayLink else { return }

            let callback: CVDisplayLinkOutputCallback = { (_, _, _, _, _, userInfo) -> CVReturn in
                let myView = Unmanaged<ScreenCaptureStreamCG>.fromOpaque(UnsafeRawPointer(userInfo!)).takeUnretainedValue()
                DispatchQueue.main.async {
                    myView.displayLinkCallback()
                }
                return kCVReturnSuccess
            }

            let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            CVDisplayLinkSetOutputCallback(displayLink, callback, userInfo)
            CVDisplayLinkStart(displayLink)
        }
    }

    /// Grab frame every X display refresh calls
    private func displayLinkCallback() {
        var frameSkips = 2

        switch refreshSpeed {
            case .fast:
                prepareFrameCapture()
                return
            case .normal: frameSkips = 3
            case .slow: frameSkips = 10
        }

        if framesSinceLastCapture == frameSkips {
            prepareFrameCapture()
            framesSinceLastCapture = 0
        } else { framesSinceLastCapture += 1 }
    }


    @objc func captureImmediately() {
        prepareFrameCapture()
    }

    func prepareFrameCapture() {
		assert(Thread.isMainThread)
        guard let window = window else { return }
        guard legalWindowNumbers.contains(window.windowNumber) else {
            NSLog("Skipping capture for uninitialized window ID \(window.windowNumber).");
            return
        }

		let canCapture = captureState.withLock { captureState in
			let canCapture = !captureState.isCapturing && !captureState.capturingDisabled
			if canCapture {
				captureState.isCapturing = true
			}
			return canCapture
		}
        guard canCapture else { return }

        let windowID = CGWindowID(window.windowNumber)
        let viewScaleFactor = window.backingScaleFactor


        let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
        var captureRect = getPreferredViewAreaInScreenCoordinates()
        captureRect.origin.y = mainDisplayBounds.height - captureRect.origin.y - captureRect.height

		captureWindowsBelow(captureRect, windowID: windowID, backingScaleFactor: viewScaleFactor)
    }

}

// MARK: - Helpers to Schedule/Prepare Capture

private extension ScreenCaptureStreamCG {

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
			captureState.withLock { captureState in
				captureState.capturingDisabled = true
			}
            view?.isHidden = true
			displayLink.enqueue { displayLink in
				if let link = displayLink { CVDisplayLinkStop(link) }
			}
        } else {
			displayLink.enqueue { displayLink in
				if let link = displayLink { CVDisplayLinkStart(link) }
			}
			captureState.withLock { captureState in
				captureState.capturingDisabled = false
				captureState.unhideOnNextDisplay = true
			}
			captureImmediately()
        }
    }
}

extension ScreenCaptureStreamCG: ViewUpdatesSubscriber {

    public func viewWillStartLiveResize() {
        markAsMoving()
    }

    public func viewDidEndLiveResize() {
        markAsStationary()
    }

}

// MARK: - Apply User Preferences

private extension ScreenCaptureStreamCG {

    @objc func updateFromDefaults() {
        refreshSpeed = refreshSpeedDefault
        preferredCaptureArea = viewAreaDefault
    }
}

// MARK: - Dispatch Queue Label

public extension ScreenCaptureStreamCG {

	private static var queueCount = 0

	static func nextDispatchQueueLabel() -> String {
		queueCount += 1
		return "\(Self.self)" + String(queueCount)
	}
}

