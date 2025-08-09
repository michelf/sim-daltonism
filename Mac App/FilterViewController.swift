
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
import MetalKit
import AVFoundation

#if os(macOS)
let forceCGCapture = UserDefaults.standard.integer(forKey: "ScreenCaptureMethod") == 0
let forceOpenGL = UserDefaults.standard.integer(forKey: "RenderingMethod") == 0
struct MetalDisabledError: Error {}
#endif

class FilterViewController: NSViewController {

    private var renderer: CaptureStreamDelegate? = nil
    private var screenCaptureStream: CaptureStream? = nil
    private weak var filterStore: FilterStore!
	#if os(macOS)
	/// Fallback for old Macs with no Metal support
	var openGLFilteredView: NSOpenGLView?
	#endif
	public var captureArea = ViewArea.underWindow {
		didSet { updateCaptureArea() }
	}

	@IBOutlet var filteredView: FilteredMetalView!
	@IBOutlet var centerCrossView: NSView?
	@IBOutlet var permissionRequestView: NSView?
	@IBOutlet var permissionRequestBackground: NSView?
	@IBOutlet var openSystemSettingsButton: NSButton?
	@IBOutlet var resizingBackgroundView: NSView?

	override func viewDidLoad() {
		if #available(macOS 13, *) {
		} else {
			openSystemSettingsButton?.title = NSLocalizedString("Open System Preferences",
				comment: "Replacement title for button 'Open System Settings' on macOS 12 and earlier (uses the name System Preferences instead of System Settings")
		}
	}
    
    static let innerCornerRadius: CGFloat =  {
        if #available(macOS 26, *) { 13 } else { 6 }
    }()

	func applyInnerCornerRadius(to view: NSView) {
		view.wantsLayer = true
		if #available(macOS 11, *) {
            view.layer?.cornerRadius = FilterViewController.innerCornerRadius
			view.layer?.cornerCurve = .continuous
			view.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
			view.layer?.masksToBounds = true
		}
		view.layer?.borderColor = NSColor.black.withAlphaComponent(0.2).cgColor
		view.layer?.borderWidth = 1
	}

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let parent = filteredView.window?.windowController as? FilterWindowController else { return }
        self.filterStore = parent.filterStore

		applyInnerCornerRadius(to: filteredView)
		applyInnerCornerRadius(to: permissionRequestBackground!)
		applyInnerCornerRadius(to: resizingBackgroundView!)

		if false, #available(macOS 10.14, *) {
			let highContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
			permissionRequestView?.appearance = NSAppearance(named: highContrast ? .accessibilityHighContrastDarkAqua : .darkAqua)
		} else {
			permissionRequestView?.appearance = NSAppearance(named: .vibrantDark)
		}

        // Grab frame on main thread
        let initialFrame = view.frame
        filteredView.frame = initialFrame

        do { try self.connectMetalViewAndFilterPipeline() }
		catch let error { NSApp.presentError(error) }


		screenCaptureStream = if #available(macOS 15, *), !forceCGCapture {
			ScreenCaptureStreamSCKit(view: filteredView, delegate: renderer)
		} else {
			ScreenCaptureStreamCG(view: filteredView, delegate: renderer)
		}

		updateCapturePermissionVisibility()

		do {
			self.screenCaptureStream?.captureRect = initialFrame
			try self.screenCaptureStream?.startSession()
		}
		catch let error { NSApp.presentError(error) }

		activateMouseEventMonitoring()
    }

    override func viewDidDisappear() {
		deaactivateMouseEventMonitoring()
        screenCaptureStream?.stopSession()
    }

	// MARK: - Mouse Tracking

	var _globalEventObserver: Any?
	var _localEventObserver: Any?

	func activateMouseEventMonitoring() {
		if _globalEventObserver == nil {
			_globalEventObserver = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
				self?.handleMouseEvent(event)
			}
		}
		if _localEventObserver == nil {
			_localEventObserver = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
				self?.handleMouseEvent(event)
				return event
			}
		}
	}
	func deaactivateMouseEventMonitoring() {
		if let globalEventObserver = _globalEventObserver {
			NSEvent.removeMonitor(globalEventObserver)
			_globalEventObserver = nil
		}
		if let localEventObserver = _localEventObserver {
			NSEvent.removeMonitor(localEventObserver)
			_localEventObserver = nil
		}
	}

	@objc func handleMouseEvent(_ event: NSEvent) {
		setWindowIgnoresMouseEventsState()
		updateCaptureArea()
	}

	func updateCaptureArea() {
		guard let window = view.window else { return }

		screenCaptureStream?.captureRect = getViewAreaInScreenCoordinates()
	}

	func getViewAreaInScreenCoordinates() -> CGRect {
		assert(Thread.isMainThread)
		let view = view
		guard let window = view.window else { return .zero }
		let viewInWindow = view.convert(view.bounds, to: window.contentView)
		var viewInScreen = window.convertToScreen(viewInWindow)

		switch captureArea {
		case .underWindow:
			return viewInScreen

		case .mousePointer:
			let mouseLocation = NSEvent.mouseLocation
			// if mouse is inside window, fall through .UnderWindow instead
			if viewInScreen.contains(mouseLocation) {
				return viewInScreen
			} else {
				viewInScreen.origin = CGPoint(x: round(mouseLocation.x), y: round(mouseLocation.y))
				let mouseView = viewInScreen.offsetBy(
					dx: -round(viewInScreen.width/2),
					dy: -round(viewInScreen.height/2))
				return mouseView
			}
		}
	}

	deinit {
		deaactivateMouseEventMonitoring()
	}

}

private extension FilterViewController {

	@objc func updateCapturePermissionVisibility() {
		let hasCapturePermission = screenCaptureStream?.checkCapturePermission() ?? true

		permissionRequestView?.isHidden = hasCapturePermission
		permissionRequestBackground?.isHidden = hasCapturePermission
		filteredView.isHidden = !hasCapturePermission
	}

	@IBAction func openPrivacyPanel(_ sender: Any) {
		openSystemSettings(panel: "Privacy_ScreenCapture", fallback: "Privacy")
	}

	private func openSystemSettings(panel: String, fallback: String? = nil) {
		let privacyPanel = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(panel)")!
		let success = NSWorkspace.shared.open(privacyPanel)
		if !success, let fallback {
			openSystemSettings(panel: fallback)
		}
	}

}

private extension FilterViewController {

    /// If supported, connect a renderer to the Metal view. Returns false if failed to setup Metal.
    func connectMetalViewAndFilterPipeline() throws {
		if let initialDevice = getPreferredMTLDevice(), !forceOpenGL {
			filteredView.device = initialDevice

			guard let renderer = MetalRenderer(mtkview: filteredView, filter: filterStore)
			else { throw MetalRendererError }

			self.renderer = renderer
			self.filteredView.delegate = renderer
		} else {
			#if os(macOS)
			// when metal device is not available,
			// use alternate implementation based on OpenGL:
			// just insert an OpenGL view as a subview of the metal view
			// to cover it entirely (a bit patchy, I know, but it works)
			let openGLView = FilteredOpenGLView(frame: filteredView.bounds)
			openGLView.autoresizingMask = [.height, .width]
			filteredView.addSubview(openGLView)
			openGLFilteredView = openGLView

			guard let renderer = OpenGLRenderer(openGLView: openGLView, filter: filterStore)
			else { throw MetalRendererError }

			self.renderer = renderer
			openGLView.delegate = renderer
			#else
			throw MetalUnsupportedError
			#endif
		}
    }

    private func getPreferredMTLDevice() -> MTLDevice? {
        if #available(macOS 10.15, *) {
            return filteredView.preferredDevice
        } else {
            return filteredView.getBestMTLDevice()
        }
    }

    @objc func setWindowIgnoresMouseEventsState() {
		guard !filteredView.isHidden else {
			self.view.window?.ignoresMouseEvents = false
			return
		}
        let viewBounds = filteredView.bounds
		let mouseLocationRect = NSRect(origin: NSEvent.mouseLocation, size: .zero)
		let locationInWindow = filteredView.window?.convertFromScreen(mouseLocationRect).origin ?? .zero
        let mouseLocationInView = filteredView.convert(locationInWindow, from: nil)
        let mouseIsInView = viewBounds.contains(mouseLocationInView)
		centerCrossView?.isHidden = mouseIsInView || captureArea != .mousePointer || filteredView.isHidden

        // Allow more room for grabbing the window resize corners
		let resizeCornerSize = CGSize(width: 15, height: 15) // from the window's edge
		let windowBounds = filteredView.window?.contentView?.bounds ?? .zero
		let insideResizeCorner = locationInWindow.y < resizeCornerSize.height && (
			mouseLocationInView.x < resizeCornerSize.width ||
			mouseLocationInView.x > windowBounds.width - resizeCornerSize.width
		)

        let newState = mouseIsInView && !insideResizeCorner
		filteredView.window?.ignoresMouseEvents = newState
		// debugging helper:
//		filteredView.alphaValue = newState ? 1 : 0.5
    }

}
