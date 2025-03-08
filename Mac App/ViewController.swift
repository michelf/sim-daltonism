
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
import MetalKit
import AVFoundation

class ViewController: NSViewController {

    @IBOutlet var filteredView: FilteredMetalView!
    private var renderer: MetalRenderer? = nil
    private var screenCaptureStream: ScreenCaptureStream? = nil
    private weak var filterStore: FilterStore!

	@IBOutlet var permissionRequestView: NSView?
	@IBOutlet var permissionRequestBackground: NSView?
	@IBOutlet var openSystemSettingsButton: NSButton?

	override func viewDidLoad() {
		if #available(macOS 13, *) {
		} else {
			openSystemSettingsButton?.title = NSLocalizedString("Open System Preferences", comment: "")
		}
	}

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let parent = filteredView.window?.windowController as? WindowController else { return }
        self.filterStore = parent.filterStore

        // Grab frame on main thread
        let initialFrame = view.frame
        filteredView.frame = initialFrame

        do { try self.connectMetalViewAndFilterPipeline() }
        catch let error { NSApp.mainWindow?.presentError(error) }


		screenCaptureStream = if #available(macOS 15, *) {
			ScreenCaptureStreamSCKit(view: filteredView,
									 window: view.window!)
		} else {
			ScreenCaptureStreamCG(view: filteredView,
								  window: view.window!)
		}

		updateCapturePermissionVisibility()

        do { try self.screenCaptureStream?.startSession(in: initialFrame, delegate: renderer!) }
        catch let error { NSApp.mainWindow?.presentError(error) }

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
		screenCaptureStream?.handleMouseEvent(event)
	}

	deinit {
		deaactivateMouseEventMonitoring()
	}

}

private extension ViewController {

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

private extension ViewController {

    /// If supported, connect a renderer to the Metal view. Returns false if failed to setup Metal.
    func connectMetalViewAndFilterPipeline() throws {

        guard let initialDevice = getPreferredMTLDevice()
        else { throw MetalUnsupportedError }

        filteredView.device = initialDevice

        guard let renderer = MetalRenderer(mtkview: filteredView, filter: filterStore)
        else { throw MetalRendererError }

        self.renderer = renderer
        self.filteredView.delegate = renderer

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
        let mouseLocationInView: CGPoint = {
            let mouseRect = NSRect(origin: NSEvent.mouseLocation, size: NSMakeSize(1, 1))
            let locationInWindow = view.window?.convertFromScreen(mouseRect).origin ?? .zero
            return view.convert(locationInWindow, from: nil)
        }()
        let mouseIsInView = viewBounds.contains(mouseLocationInView)

        // To allow more room to grab the window edges, calculate inset
        // bottom and side bounds so that grabbing the window edge
        // is easier
        let resizeCornerSize = CGFloat(12)
        let insetRectForEasierWindowResizing = viewBounds
            .insetBy(dx: resizeCornerSize, dy: resizeCornerSize / 2)
            .offsetBy(dx: 0, dy: resizeCornerSize)

        let newState = mouseIsInView && insetRectForEasierWindowResizing.contains(mouseLocationInView)
        self.view.window?.ignoresMouseEvents = newState
    }

}
