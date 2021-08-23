
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
    private var screenCapturer: ScreenCapturer? = nil
    private var mouseTimer: Timer?
    private weak var filterStore: FilterStore!

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let parent = filteredView.window?.windowController as? WindowController else { return }
        self.filterStore = parent.filterStore

        // Grab frame on main thread
        let initialFrame = view.frame
        filteredView.frame = initialFrame

        do { try self.connectMetalViewAndFilterPipeline() }
        catch let error { NSApp.mainWindow?.presentError(error) }

        screenCapturer = CGWindowListScreenCapturer(view: filteredView,
                                                    window: view.window!,
                                                    queue: filterStore.queue)

        do { try self.screenCapturer?.startSession(in: initialFrame, delegate: renderer!) }
        catch let error { NSApp.mainWindow?.presentError(error) }

        DispatchQueue.main.async {
            self.setupTimerToPeriodicallyTrackMouse()
        }
    }

    override func viewDidDisappear() {
        mouseTimer?.invalidate()
        mouseTimer = nil
        screenCapturer?.stopSession()
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

    func setupTimerToPeriodicallyTrackMouse() {
        mouseTimer = Timer(timeInterval: 0.25, target: self, selector: #selector(setWindowIgnoresMouseEventsState), userInfo: nil, repeats: true)
        RunLoop.current.add(mouseTimer!, forMode: .common)
        mouseTimer?.tolerance = 0.2
    }

    @objc func setWindowIgnoresMouseEventsState() {
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
