
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
