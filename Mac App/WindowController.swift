
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


class WindowController: NSWindowController, NSWindowDelegate {

    /// Unique instance per window
    var filterStore: FilterStore = FilterStore()

    // MARK: - User Settings

    var visionType = UserDefaults.getVision() {
        didSet {
            setVisionTypeDefault()
            applyVisionType()
        }
    }

    func setVisionTypeDefault() {
        UserDefaults.setVision(visionType)
    }

    private func applyVisionType() {
        guard let window = self.window else { return }
        window.title = visionType.name
        filterStore.setVision(to: visionType)
        FilterWindowManager.shared.changedWindowController(self)
        window.invalidateRestorableState()
    }

    var simulation = UserDefaults.getSimulation() {
        didSet {
            setSimulationDefault()
            applySimulation()
        }
    }

    func setSimulationDefault() {
        UserDefaults.setSimulation(simulation)
    }

    fileprivate func applySimulation() {
        filterStore.setSimulation(to: simulation)
    }


    // MARK: - Manage Window

    fileprivate static let windowLevel = NSWindow.Level(Int(CGWindowLevelForKey(CGWindowLevelKey.assistiveTechHighWindow) + 1))

    override func windowDidLoad() {
        super.windowDidLoad()

        // cannot set from IB:
        // Note: window level is set to 1 above Red Stripe's window level
        // so you can use the two together.
        window?.level = WindowController.windowLevel
        window?.hidesOnDeactivate = false
        window?.standardWindowButton(.zoomButton)?.isEnabled = false
        if #available(OSX 10.12, *) {
            window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .participatesInCycle]
        } else {
            window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // dragging not working with .participatesInCycle
        }
        window?.styleMask.formUnion(.nonactivatingPanel)
        window?.restorationClass = FilterWindowManager.self

        let accessory = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "WindowControls") as! NSTitlebarAccessoryViewController
        accessory.layoutAttribute = .right
        window?.addTitlebarAccessoryViewController(accessory)

        applyVisionType()
    }

    /// Position the window so it has a different origin than other filter
    /// windows based on the registered list of window controllers in
    /// `FilterWindowManager`.
    func cascade() {
        var windowControllers = FilterWindowManager.shared.windowControllers
        windowControllers.remove(self)
    baseLoop:
        while !windowControllers.isEmpty {
            guard let frame = window?.frame else { return }
            for otherController in windowControllers {
                if otherController.window?.frame.origin == frame.origin {
                    window?.setFrameOrigin(frame.offsetBy(dx: 30, dy: -30).origin)
                    windowControllers.remove(otherController)
                    continue baseLoop
                }
            }
            break // check all remaining controllers
        }
    }

    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        WindowRestoration.encodeRestorable(state: state, visionType, simulation)
    }
    
    func window(_ window: NSWindow, didDecodeRestorableState state: NSCoder) {
        (visionType, simulation) = WindowRestoration.decodeRestorable(state: state)
    }

    override func showWindow(_ sender: Any?) {
        FilterWindowManager.shared.addWindowController(self)
        super.showWindow(sender)
    }

    func windowWillClose(_ notification: Notification) {
        FilterWindowManager.shared.removeWindowController(self)
    }

    // MARK: - Menu Intents (Unique state per window)

    @IBAction func adoptVisionTypeSetting(_ sender: NSMenuItem) {
        visionType = .init(rawValue: sender.tag) ?? .defaultValue
    }

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action! {
            case #selector(adoptVisionTypeSetting(_:)):
                menuItem.state = visionType.rawValue == menuItem.tag ? .on : .off
                return true

            case #selector(adoptSimulationSetting):
                menuItem.state = simulation.rawValue == menuItem.tag ? .on : .off
                return true

            default:
                return false
        }
    }

    @IBAction func adoptSimulationSetting(_ sender: NSMenuItem) {
        simulation = .init(runtime: sender.tag)
    }

}
