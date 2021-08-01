//  © 2021 Ryan Ferrell. github.com/importRyan

#if canImport(AppKit)
import AppKit
import MetalKit

extension NSView {
    
    /// Find Metal device driving the screen containing the view's parent window to avoid copying data between GPUs. If not found, defaults to main display's Metal device. Returns nil if no Metal support found.
    func getBestMTLDevice() -> MTLDevice? {
        let displayID = getParentWindowDisplayID() ?? CGMainDisplayID()
        return CGDirectDisplayCopyCurrentMetalDevice(displayID)
    }

    func getParentWindowDisplayID() -> CGDirectDisplayID? {
        window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

#endif
