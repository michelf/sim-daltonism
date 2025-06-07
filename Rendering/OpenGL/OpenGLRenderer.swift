
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
}

extension OpenGLRenderer {

    func render(_ image: CIImage) {
		guard let openGLView else { return }
        self.image = filterStore?.applyFilter(to: image) ?? image
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

		rescaleIfNeeded(drawableSize: drawableSize, imageExtent: image.extent)

		let drawableRect = CGRect(origin: .zero, size: drawableSize)

		view.openGLContext!.makeCurrentContext()
		context?.draw(image, in: drawableRect, from: image.extent)
		glFlush()
    }

	private func rescaleIfNeeded(drawableSize: CGSize, imageExtent: CGRect) {
		guard drawableSize != imageExtent.size else { return }

		// aspect-fit transform
		let ratioX = drawableSize.width / imageExtent.width
		let ratioY = drawableSize.height / imageExtent.height
		let scale: CGFloat
		var translationX: CGFloat = 0
		var translationY: CGFloat = 0
		if ratioX < ratioY {
			scale = ratioY
			translationX -= round((imageExtent.width * scale - drawableSize.width) / 2)
		} else {
			scale = ratioX
			translationY -= round((imageExtent.height * scale - drawableSize.height) / 2)
		}

		let transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: translationX, y: translationY)

		image = image.transformed(by: transform, highQualityDownsample: false)

	}

}
