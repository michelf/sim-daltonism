
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

import Foundation
import MetalKit
@preconcurrency import CoreImage

/// Manages an MTKView by enqueing frames for rendering and responding to changes affecting the drawable size
@MainActor
class MetalRenderer: NSObject {

	struct Context: @unchecked Sendable {
		let ci: CIContext
		let metalLayer: CAMetalLayer
		let commandQueue: MTLCommandQueue
	}
    private let image = Mutex(CIImage())
	private let context: Mutex<(ci: CIContext, metalLayer: CAMetalLayer, commandQueue: MTLCommandQueue)>
	private var workingColorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)!
	weak var mtkview: MTKView?
    nonisolated private let filterStore: FilterStore?
	private let drawableSize: Mutex<CGSize>

    init?(mtkview: MTKView, filter: FilterStore) {
        guard let device = mtkview.device,
              let commandQueue = device.makeCommandQueue()
        else { return nil }
        self.mtkview = mtkview
		self.context = Mutex((
			CIContext(mtlDevice: device, options: [.workingColorSpace: workingColorSpace]),
			metalLayer: mtkview.layer as! CAMetalLayer,
			commandQueue: commandQueue
		))
        self.filterStore = filter
		self.drawableSize = Mutex(mtkview.drawableSize)
    }
}

extension MetalRenderer: CaptureStreamDelegate {

    /// Called on the ImageCapturer's queue,
    /// which should be the CIFilter queue
    ///
    nonisolated func didCaptureFrame(image: CIImage) {
        render(image)
    }

	nonisolated func currentRenderedImage() -> CIImage {
		self.image.withLock { $0 }
	}

}

extension MetalRenderer {
    
    /// Prepare the frame received by applying available filter(s). Call MTKView.draw(in:) to execute.
	nonisolated func render(_ image: CIImage) {
		self.image.withLock { $0 = image }
		self.draw()
    }
}

extension MetalRenderer: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.drawableSize.withLock { $0 = size }
		#if os(macOS)
		view.colorspace = CGDisplayCopyColorSpace(CGMainDisplayID())
		#endif
    }

	func draw(in view: MTKView) {
		assert(mtkview === view)
		assert(mtkview?.layer === context.withLock { $0.metalLayer })
		draw()
	}

	nonisolated func draw() {
		let drawableSize = self.drawableSize.withLock { $0 }
		var image = image.withLock { $0 }
		image = image.rescaledCentered(inFrame: drawableSize)
		image = filterStore?.applyFilter(to: image) ?? image
		
		#if os(macOS)
		let colorspace = CGDisplayCopyColorSpace(CGMainDisplayID())
		#else
		let colorspace = CGColorSpaceCreateDeviceRGB()
		#endif

		context.withLock { context in
			if context.metalLayer.drawableSize != drawableSize {
				// Sometime after moving window between 1x and 2x screens
				// the drawable size isn't updated correctly.
				context.metalLayer.drawableSize = drawableSize
			}

			guard let buffer = context.commandQueue.makeCommandBuffer(),
				  let currentDrawable = context.metalLayer.nextDrawable()
			else { return }

			// Note: activating Xcode's thread performance checker can
			// occasionally cause crashes on the CI rendering queue.
			context.ci.render(
				image,
				to: currentDrawable.texture,
				commandBuffer: buffer,
				bounds: CGRect(origin: .zero, size: drawableSize),
				colorSpace: colorspace
			)

			buffer.present(currentDrawable)
			buffer.commit()
		}
    }
    
}
