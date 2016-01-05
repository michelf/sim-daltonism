
//	Copyright 2015-2016 Michel Fortin
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
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateFromDefaults", name: NSUserDefaultsDidChangeNotification, object: nil)
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	var viewArea = ViewArea.UnderWindow

	var updateInterval: NSTimeInterval = 0.05 {
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

	override func viewWillMoveToWindow(newWindow: NSWindow?) {
		super.viewWillMoveToWindow(newWindow)
		if let window = window {
			NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidMoveNotification, object: window)
			NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowWillStartLiveResizeNotification, object: window)
			NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidEndLiveResizeNotification	, object: window)
			NSNotificationCenter.defaultCenter().removeObserver(self, name: WindowWillStartDraggingNotification, object: window)
			NSNotificationCenter.defaultCenter().removeObserver(self, name: WindowDidEndDraggingNotification	, object: window)
			NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidChangeOcclusionStateNotification	, object: window)
		}
		if let newWindow = newWindow {
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "recaptureAsync", name: NSWindowDidMoveNotification, object: newWindow)
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowDidEndLiveResize:", name: NSWindowDidEndLiveResizeNotification, object: newWindow)
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWillStartLiveResize:", name: NSWindowWillStartLiveResizeNotification, object: newWindow)
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWillStartLiveResize:", name: WindowWillStartDraggingNotification, object: newWindow)
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowDidEndLiveResize:", name: WindowDidEndDraggingNotification, object: newWindow)
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowDidChangeOcclusionState:", name: NSWindowDidChangeOcclusionStateNotification, object: newWindow)
		}
	}

	var resizingOrMoving: Bool = false { didSet { updateCapturingState() } }
	var occluded: Bool = false { didSet { updateCapturingState() } }

	func updateCapturingState() {
		let shouldDisable = resizingOrMoving || occluded;
		if shouldDisable {
			capturingDisabled = true
			hidden = true
		} else {
			capturingDisabled = false
			recaptureAsync()
			unhideOnNextDisplay = true
		}
	}

	@objc func windowWillStartLiveResize(notification: NSNotification) {
		resizingOrMoving = true
	}
	@objc func windowDidEndLiveResize(notification: NSNotification) {
		resizingOrMoving = false
	}

	@objc func windowDidChangeOcclusionState(notification: NSNotification) {
		if !window!.occlusionState.contains(NSWindowOcclusionState.Visible) {
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
			updateTimer = NSTimer(timeInterval: updateInterval, target: self, selector: "recaptureIfNeeded", userInfo: nil, repeats: true)
			NSRunLoop.currentRunLoop().addTimer(updateTimer!, forMode: NSRunLoopCommonModes)
		} else {
			updateTimer = nil
		}
	}

	private var counter: Int = 0
	@objc func recaptureIfNeeded() {
		let mouseLocation = NSEvent.mouseLocation()
		let mouseLocationInWindow = self.window!.convertRectFromScreen(NSRect(origin: mouseLocation, size: NSMakeSize(1, 1))).origin
		let mouseLocationInView = self.convertPoint(mouseLocationInWindow, fromView: nil)
		let mouseInView = CGRectContainsPoint(self.bounds, mouseLocationInView)
		if mouseInView {
			self.window?.ignoresMouseEvents = mouseInView
		} else {
			self.window?.ignoresMouseEvents = mouseInView
		}
		// Update once every 5 fire or whenever the mouse moves.
		if counter++ > 5 || lastMouseLocation != mouseLocation {
			counter = 0
			redrawCapture(async: true)
		}
	}

	@objc func recaptureAsync() {
		redrawCapture(async: true)
	}

	var updateTimer: NSTimer?
	var lastMouseLocation: NSPoint = NSMakePoint(0, 0)

	override func drawRect(dirtyRect: NSRect) {
		redrawCapture(async: false)
	}

	override var opaque: Bool { get { return false } }
	override var wantsDefaultClipping: Bool { get { return false } }

	private var viewData: CFMutableData?
	private var viewDataSize: size_t = 0
	private var imageData: CGDataProvider?

	func getViewAreaRect() -> CGRect {
		let viewBounds = self.bounds
		var viewRect = window!.convertRectToScreen(convertRect(viewBounds, toView: window!.contentView))
		switch viewArea {
		case .MousePointer:
			let mouseLocation = NSEvent.mouseLocation()
			// if mouse is inside window, fall through .UnderWindow instead
			if !viewRect.contains(mouseLocation) {
				viewRect.origin = mouseLocation
				viewRect.offsetInPlace(dx: -round(viewRect.width/2), dy: -round(viewRect.height/2))
				return viewRect
			}
			fallthrough
		case .UnderWindow:
			return NSRectToCGRect(viewRect);
		}
	}

	func redrawCapture(async async: Bool) {
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

		if async {
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
				self.redrawCaptureInBackground(captureRect, windowID: windowID, backingScaleFactor: viewScaleFactor)
			}
		} else {
			self.redrawCaptureInBackground(captureRect, windowID: windowID, backingScaleFactor: viewScaleFactor)
		}
	}

	func redrawCaptureInBackground(captureRect: CGRect, windowID: CGWindowID, backingScaleFactor: CGFloat) {
		capturing = false
		if capturingDisabled {
			return
		}
		if let captureImage = CGWindowListCreateImage(captureRect, CGWindowListOption.OptionOnScreenBelowWindow, windowID, CGWindowImageOption.Default)

		{
			if capturingDisabled {
				return
			}
			displayImage(captureImage, scale: 1)
			if unhideOnNextDisplay {
				unhideOnNextDisplay = false
				dispatch_async(dispatch_get_main_queue()) {
					self.hidden = false
				}
			}
		}
	}

}

private func startValueFor(center center: Int, screenSize: Int, viewSize: Int) -> Int {
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

private func screenForDirectDisplayID(display: CGDirectDisplayID) -> NSScreen? {
	for screen in NSScreen.screens() ?? [] {
		if (screen.deviceDescription["NSScreenNumber"] as! NSNumber).unsignedIntValue == display {
			return screen
		}
	}
	return nil
}
