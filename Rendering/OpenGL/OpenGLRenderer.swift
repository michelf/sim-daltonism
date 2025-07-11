
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

@MainActor
class OpenGLRenderer: NSObject {

    private let image = Mutex(CIImage())
	private let context: Mutex<(ci: CIContext, openGL: NSOpenGLContext)>
	private var colorSpace = CGDisplayCopyColorSpace(CGMainDisplayID())
	private var workingColorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)!
    weak var openGLView: NSOpenGLView?
    nonisolated private let filterStore: FilterStore
	private let drawableSize: Mutex<CGSize>

	init?(openGLView: NSOpenGLView, filter: FilterStore) {
        self.openGLView = openGLView
        self.filterStore = filter
		self.drawableSize = Mutex(openGLView.convertToBacking(openGLView.bounds.size))
		let pf = openGLView.pixelFormat ?? Self._defaultPixelFormat
		guard let openGLContext = openGLView.openGLContext else {
			return nil
		}
		self.context = Mutex((
			ci: CIContext(cglContext: openGLView.openGLContext!.cglContextObj!,
						  pixelFormat: pf.cglPixelFormatObj, colorSpace: colorSpace, options: [.workingColorSpace: workingColorSpace]),
			openGL: openGLContext,
		))
		super.init()
    }

	private static let _defaultPixelFormat = NSOpenGLPixelFormat(attributes: [
		UInt32(NSOpenGLPFAAccelerated),
		UInt32(NSOpenGLPFANoRecovery),
		UInt32(NSOpenGLPFAColorSize), 32,
		UInt32(NSOpenGLPFAAllowOfflineRenderers),
		0,
	])!
}

extension OpenGLRenderer: CaptureStreamDelegate {

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

extension OpenGLRenderer {

	nonisolated func render(_ image: CIImage) {
//		guard let openGLView else { return }
		self.image.withLock { $0 = image }
		self.draw()
    }
}

extension OpenGLRenderer {

	func didResize(to drawableSize: CGSize) {
		self.drawableSize.withLock { $0 = drawableSize }
	}

	nonisolated func draw() {
		let drawableSize = self.drawableSize.withLock { $0 }

		var image = image.withLock { $0 }
		image = image.rescaledCentered(inFrame: drawableSize)
		image = filterStore.applyFilter(to: image) ?? image

		let drawableRect = CGRect(origin: .zero, size: drawableSize)

		context.withLock { context in
			context.openGL.makeCurrentContext()
			context.ci.draw(image, in: drawableRect, from: image.extent)
			glFlush()
		}
    }

}
