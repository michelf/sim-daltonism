
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

import Foundation
import MetalKit

/// Manages an MTKView by enqueing frames for rendering and responding to changes affecting the drawable size
class MetalRenderer: NSObject {

    private var image = CIImage()
    private var context: CIContext?
    private var commandQueue: MTLCommandQueue
	private var workingColorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)!
    weak var mtkview: MTKView?
    private weak var filterStore: FilterStore?
    
    init?(mtkview: MTKView, filter: FilterStore) {
        guard let device = mtkview.device,
              let commandQueue = device.makeCommandQueue()
        else { return nil }
        self.mtkview = mtkview
        self.commandQueue = commandQueue
        self.filterStore = filter
		context = CIContext(mtlDevice: device, options: [.workingColorSpace: workingColorSpace])
    }
}

extension MetalRenderer: ScreenCaptureStreamDelegate {

    /// Called on the ImageCapturer's queue,
    /// which should be the CIFilter queue
    ///
    func didCaptureFrame(image: CIImage) {
        render(image)
    }
}

extension MetalRenderer {
    
    /// Prepare the frame received by applying available filter(s). Call MTKView.draw(in:) to execute.
    func render(_ image: CIImage) {
        self.image = filterStore?.applyFilter(to: image) ?? image
        mtkview?.draw()
    }
}

extension MetalRenderer: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Auto-resizing
		view.colorspace = CGDisplayCopyColorSpace(CGMainDisplayID())
    }

    /// Queues rendering commands into GPU
    func draw(in view: MTKView) {
        
        guard let buffer = commandQueue.makeCommandBuffer(),
              let currentDrawable = view.currentDrawable
        else { return }

        rescaleIfNeeded(drawableSize: view.drawableSize, imageExtent: image.extent)

        context?.render(
            image,
            to: currentDrawable.texture,
            commandBuffer: buffer,
			bounds: CGRect(origin: .zero, size: view.drawableSize),
			colorSpace: view.colorspace ?? CGColorSpaceCreateDeviceRGB()
        )

        buffer.present(currentDrawable)
        buffer.commit()
    }

    /// When Metal is rendering to a different scale factor than the image delivered
    /// (e.g., view is in Retina screen, mouse pointer is in non-Retina screen),
    /// then scale the CIImage to fit the Metal drawable.
    private func rescaleIfNeeded(drawableSize: CGSize, imageExtent: CGRect) {
        guard drawableSize != imageExtent.size else { return }

        let scaling = CGAffineTransform(
            scaleX: drawableSize.width / imageExtent.width,
            y: drawableSize.height / imageExtent.height
        )

        image = image.transformed(by: scaling, highQualityDownsample: false)

    }
    
}
