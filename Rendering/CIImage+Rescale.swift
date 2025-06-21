import CoreImage

extension CIImage {

	func rescaledCentered(inFrame drawableSize: CGSize) -> CIImage {
		let imageExtent = self.extent
		guard drawableSize != imageExtent.size else { return self }
		guard !imageExtent.isEmpty else { return self }
		let drawableRect = CGRect(origin: .zero, size: drawableSize)

		// aspect-fit transform
		let ratioX = drawableSize.width / imageExtent.width
		let ratioY = drawableSize.height / imageExtent.height
		let scale: CGFloat
		if ratioX < ratioY {
			scale = ratioY
		} else {
			scale = ratioX
		}

		let transform = CGAffineTransform.identity
			.translatedBy(x: drawableRect.midX, y: drawableRect.midY)
			.scaledBy(x: scale, y: scale)
			.translatedBy(x: -imageExtent.midX, y: -imageExtent.midY)

		return self.transformed(by: transform, highQualityDownsample: false)
	}

}
