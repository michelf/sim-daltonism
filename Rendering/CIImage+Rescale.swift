import CoreImage

extension CIImage {

	func rescaledCentered(inFrame drawableSize: CGSize) -> CIImage {
		let imageExtent = self.extent
		guard drawableSize != imageExtent.size else { return self }
		guard !imageExtent.isEmpty else { return self }

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

		return self.transformed(by: transform, highQualityDownsample: false)
	}

}
