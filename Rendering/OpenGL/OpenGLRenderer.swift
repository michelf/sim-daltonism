
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

class OpenGLRenderer: NSObject {

    private var image = CIImage()
    private var context: CIContext?
	private var colorSpace = CGDisplayCopyColorSpace(CGMainDisplayID())
	private var workingColorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)!
    weak var openGLView: NSOpenGLView?
    private weak var filterStore: FilterStore?
	private var drawableSizeLock = NSLock()
	private var drawableSize: CGSize
	private var glDrawingLock = NSLock()

	init?(openGLView: NSOpenGLView, filter: FilterStore) {
        self.openGLView = openGLView
        self.filterStore = filter
		self.drawableSize = openGLView.convertToBacking(openGLView.bounds.size)
		let pf = openGLView.pixelFormat ?? Self._defaultPixelFormat
		self.context = CIContext(cglContext: openGLView.openGLContext!.cglContextObj!,
								 pixelFormat: pf.cglPixelFormatObj, colorSpace: colorSpace, options: [.workingColorSpace: workingColorSpace])
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
    func didCaptureFrame(image: CIImage) {
        render(image)
    }

	func currentRenderedImage() -> CIImage {
		self.image
	}

}

extension OpenGLRenderer {

    func render(_ image: CIImage) {
		guard let openGLView else { return }
        self.image = image
		self.draw(in: openGLView)
    }
}

extension OpenGLRenderer {

	func didResize(to drawableSize: CGSize) {
		drawableSizeLock.lock()
		self.drawableSize = drawableSize
		drawableSizeLock.unlock()
	}

	func draw(in view: NSOpenGLView) {
		drawableSizeLock.lock()
		let drawableSize = self.drawableSize
		drawableSizeLock.unlock()

		var image = image.rescaledCentered(inFrame: drawableSize)
		image = filterStore?.applyFilter(to: image) ?? image

		let drawableRect = CGRect(origin: .zero, size: drawableSize)

		view.openGLContext!.makeCurrentContext()
		context?.draw(image, in: drawableRect, from: image.extent)
		glFlush()
    }

}
