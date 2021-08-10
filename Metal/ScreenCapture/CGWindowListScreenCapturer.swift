
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

public class CGWindowListScreenCapturer {

    public weak var delegate: ScreenCaptureDelegate? = nil // Recipient of captured CIImages
    private weak var view: FilteredMetalView? = nil // Rendering view to read geometry
    private weak var window: NSWindow? = nil // Parent window to read geometry

    // Gating and capture frequency
    private var refreshSpeed: RefreshSpeed = .normal
    private var framesSinceLastCapture = 0
    private var displayLink: CVDisplayLink? = nil

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
        view.viewUpdatesSubscriber = self
        updateFromDefaults()
    }

}

// MARK: - Setup

extension CGWindowListScreenCapturer: ScreenCapturer {

    public func stopSession() {
        NotificationCenter.default.removeObserver(self)
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    public func startSession(in frame: NSRect, delegate: ScreenCaptureDelegate) throws {
        self.delegate = delegate
        monitorUserPreferences()
        guard let window = window else { return }
        setupMonitorsForInteraction(with: window)
        createDisplayLink()
    }

}

private extension CGWindowListScreenCapturer {

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

private extension CGWindowListScreenCapturer {

    func captureWindowsBelow(_ captureRect: CGRect, windowID: CGWindowID, backingScaleFactor: CGFloat) {
        defer { isCapturing = false }
        guard !capturingDisabled else { return }

        guard let captureImage = CGWindowListCreateImage(captureRect,.optionOnScreenBelowWindow, windowID, [])
        else { return }

        guard !capturingDisabled else { return }

        delegate?.didCaptureFrame(image: CIImage(cgImage: captureImage))

        afterCapturingUnhideOnNextDisplayIfNeeded()
    }

    func afterCapturingUnhideOnNextDisplayIfNeeded() {
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

private extension CGWindowListScreenCapturer {

    private func createDisplayLink() {
        queue?.async { [weak self] in
            guard let self = self else { return }
            CVDisplayLinkCreateWithActiveCGDisplays(&self.displayLink)
            guard let displayLink = self.displayLink else { return }

            let callback: CVDisplayLinkOutputCallback = { (_, _, _, _, _, userInfo) -> CVReturn in
                let myView = Unmanaged<CGWindowListScreenCapturer>.fromOpaque(UnsafeRawPointer(userInfo!)).takeUnretainedValue()
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
        guard let window = window else { return }
        guard legalWindowNumbers.contains(window.windowNumber) else {
            NSLog("Skipping capture for uninitialized window ID \(window.windowNumber).");
            return
        }

        let canCapture = !isCapturing && !capturingDisabled
        guard canCapture else { return }
        isCapturing = true

        let windowID = CGWindowID(window.windowNumber)
        let viewScaleFactor = window.backingScaleFactor


        let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
        var captureRect = getPreferredViewAreaInScreenCoordinates()
        captureRect.origin.y = mainDisplayBounds.height - captureRect.origin.y - captureRect.height

        queue?.async { [weak self] in
            self?.captureWindowsBelow(captureRect, windowID: windowID, backingScaleFactor: viewScaleFactor)
        }
    }

}

// MARK: - Helpers to Schedule/Prepare Capture

private extension CGWindowListScreenCapturer {

    func getPreferredViewAreaInScreenCoordinates() -> CGRect {
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
            if let link = displayLink { CVDisplayLinkStop(link) }
        } else {
            if let link = displayLink { CVDisplayLinkStart(link) }
            capturingDisabled = false
            captureImmediately()
            unhideOnNextDisplay = true
        }
    }
}

extension CGWindowListScreenCapturer: ViewUpdatesSubscriber {

    public func viewWillStartLiveResize() {
        markAsMoving()
    }

    public func viewDidEndLiveResize() {
        markAsStationary()
    }

}

// MARK: - Apply User Preferences

private extension CGWindowListScreenCapturer {

    @objc func updateFromDefaults() {
        refreshSpeed = refreshSpeedDefault
        preferredCaptureArea = viewAreaDefault
    }
}
