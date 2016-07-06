
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

class FilteredView: OpenGLPixelBufferView {

	required init?(coder: NSCoder) {
	    super.init(coder: coder)
		updateFromDefaults()
		NotificationCenter.default.addObserver(self, selector: #selector(updateFromDefaults), name: UserDefaults.didChangeNotification, object: nil)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	var viewArea = ViewArea.underWindow

	var updateInterval: TimeInterval = 0.05 {
		didSet {
			prepareTimer()
		}
	}

	func makeFilter() -> SimDaltonismFilter {
		return SimDaltonismFilter()
	}

	override var filter: OpenGLShaderFilter! {
		get {
			guard let filter = super.filter else {
				let filter = makeFilter()
				super.filter = filter
				return filter
			}
			return filter
		}
		set {
			super.filter = newValue
		}
	}

	override func viewWillMove(toWindow newWindow: NSWindow?) {
		super.viewWillMove(toWindow: newWindow)
		if let window = window {
			NotificationCenter.default.removeObserver(self, name: .NSWindowDidMove, object: window)
			NotificationCenter.default.removeObserver(self, name: .NSWindowWillStartLiveResize, object: window)
			NotificationCenter.default.removeObserver(self, name: .NSWindowDidEndLiveResize	, object: window)
			NotificationCenter.default.removeObserver(self, name: Window.willStartDragging, object: window)
			NotificationCenter.default.removeObserver(self, name: Window.didEndDragging	, object: window)
			NotificationCenter.default.removeObserver(self, name: .NSWindowDidChangeOcclusionState	, object: window)
		}
		if let newWindow = newWindow {
			NotificationCenter.default.addObserver(self, selector: #selector(recaptureAsync), name: .NSWindowDidMove, object: newWindow)
			NotificationCenter.default.addObserver(self, selector: #selector(windowDidEndLiveResizeOrMove(_:)), name: .NSWindowDidEndLiveResize, object: newWindow)
			NotificationCenter.default.addObserver(self, selector: #selector(windowWillStartLiveResizeOrMove(_:)), name: .NSWindowWillStartLiveResize, object: newWindow)
			NotificationCenter.default.addObserver(self, selector: #selector(windowWillStartLiveResizeOrMove(_:)), name: Window.willStartDragging, object: newWindow)
			NotificationCenter.default.addObserver(self, selector: #selector(windowDidEndLiveResizeOrMove(_:)), name: Window.didEndDragging, object: newWindow)
			NotificationCenter.default.addObserver(self, selector: #selector(windowDidChangeOcclusionState(_:)), name: .NSWindowDidChangeOcclusionState, object: newWindow)
		}
	}

	var resizingOrMoving: Bool = false { didSet { updateCapturingState() } }
	var occluded: Bool = false { didSet { updateCapturingState() } }

	func updateCapturingState() {
		let shouldDisable = resizingOrMoving || occluded;
		if shouldDisable {
			capturingDisabled = true
			isHidden = true
		} else {
			capturingDisabled = false
			recaptureAsync()
			unhideOnNextDisplay = true
		}
	}

	@objc func windowWillStartLiveResizeOrMove(_ notification: Notification) {
		resizingOrMoving = true
	}
	@objc func windowDidEndLiveResizeOrMove(_ notification: Notification) {
		resizingOrMoving = false
	}

	@objc func windowDidChangeOcclusionState(_ notification: Notification) {
		if !window!.occlusionState.contains(NSWindowOcclusionState.visible) {
			occluded = true
		} else {
			occluded = false
		}
	}

	@objc func updateFromDefaults() {
		updateInterval = refreshSpeedDefault.updateInterval
		viewArea = viewAreaDefault
	}

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		prepareTimer()
	}

	func prepareTimer() {
		updateTimer?.invalidate()
		if window != nil {
			updateTimer = Timer(timeInterval: updateInterval, target: self, selector: #selector(recaptureIfNeeded), userInfo: nil, repeats: true)
			RunLoop.current.add(updateTimer!, forMode: RunLoopMode.commonModes)
			updateTimer!.tolerance = updateInterval / 10
		} else {
			updateTimer = nil
		}
	}

	private var counter: Int = 0
	@objc func recaptureIfNeeded() {
		let viewBounds = self.bounds
		let mouseLocation = NSEvent.mouseLocation()
		let mouseLocationInWindow = self.window!.convertFromScreen(NSRect(origin: mouseLocation, size: NSMakeSize(1, 1))).origin
		let mouseLocationInView = self.convert(mouseLocationInWindow, from: nil)
		let mouseInView = viewBounds.contains(mouseLocationInView)
		let resizeCornerSize = CGFloat(8)
		self.window?.ignoresMouseEvents = mouseInView && (
			viewBounds.offsetBy(dx: 0, dy: resizeCornerSize).contains(mouseLocationInView) ||
			viewBounds.insetBy(dx: resizeCornerSize, dy: 0).contains(mouseLocationInView))

		// Update once every 5 fire or whenever the mouse moves.
		counter += 1
		if counter > 5 || lastMouseLocation != mouseLocation {
			counter = 0
			redrawCaptureAsync()
		}
	}

	@objc func recaptureAsync() {
		redrawCaptureAsync()
	}

	var updateTimer: Timer?
	var lastMouseLocation: NSPoint = NSMakePoint(0, 0)

	override func draw(_ dirtyRect: NSRect) {
		// Note: this will actually just schedule a new capture and redraw on
		// a background thread. No real drawing done before the function returns.
		redrawCaptureAsync()
	}

	override var isOpaque: Bool { get { return false } }
	override var wantsDefaultClipping: Bool { get { return false } }

	private var viewData: CFMutableData?
	private var viewDataSize: size_t = 0
	private var imageData: CGDataProvider?

	func getViewAreaRect() -> CGRect {
		let viewBounds = self.bounds
		var viewRect = window!.convertToScreen(convert(viewBounds, to: window!.contentView))
		switch viewArea {
		case .mousePointer:
			let mouseLocation = NSEvent.mouseLocation()
			// if mouse is inside window, fall through .UnderWindow instead
			if !viewRect.contains(mouseLocation) {
				viewRect.origin = mouseLocation
				viewRect.offsetInPlace(dx: -round(viewRect.width/2), dy: -round(viewRect.height/2))
				return viewRect
			}
			fallthrough
		case .underWindow:
			return NSRectToCGRect(viewRect);
		}
	}

	func redrawCaptureAsync() {
		if window == nil {
			return
		}
		let windowNumber = window!.windowNumber
		if windowNumber <= 0 || windowNumber > Int(CGWindowID.max) {
			NSLog("Skipping capture for uninitialized window ID \(windowNumber).");
			return
		}
		if capturing || capturingDisabled {
			return
		}
		capturing = true

		let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())

		let viewScaleFactor = self.window!.backingScaleFactor

		var captureRect = getViewAreaRect();
		captureRect.origin.y = mainDisplayBounds.height - captureRect.origin.y - captureRect.height;

		let windowID = CGWindowID(windowNumber)

		DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes.qosDefault).async {
			self.redrawCaptureInBackground(captureRect, windowID: windowID, backingScaleFactor: viewScaleFactor)
		}
	}

	func redrawCaptureInBackground(_ captureRect: CGRect, windowID: CGWindowID, backingScaleFactor: CGFloat) {
		defer { capturing = false }
		if capturingDisabled {
			return
		}
		if let captureImage = CGWindowListCreateImage(captureRect, CGWindowListOption.optionOnScreenBelowWindow, windowID, CGWindowImageOption())

		{
			if capturingDisabled {
				return
			}
			display(captureImage, scale: 1)
			if unhideOnNextDisplay {
				DispatchQueue.main.async {
					self.unhideOnNextDisplay = false
					self.isHidden = false
				}
			}
		}
	}

}

private func startValueFor(center: Int, screenSize: Int, viewSize: Int) -> Int {
	var startValue = center - viewSize / 2
	if viewSize >= screenSize {
		startValue = screenSize - viewSize / 2
		startValue /= 2 // divide in signed mode
	} else if startValue < 0 {
		startValue = 0
	} else if startValue + viewSize > screenSize {
		startValue = screenSize - viewSize
	}
	return startValue
}

private func screenForDirectDisplayID(_ display: CGDirectDisplayID) -> NSScreen? {
	for screen in NSScreen.screens() ?? [] {
		if (screen.deviceDescription["NSScreenNumber"] as! NSNumber).uint32Value == display {
			return screen
		}
	}
	return nil
}
