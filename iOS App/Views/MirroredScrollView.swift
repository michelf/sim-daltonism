
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

import UIKit

class MirroredScrollView: UIScrollView {

	private var mirrorView: FilteredMetalView?
	private var renderer: MetalRenderer?

	override func didMoveToWindow() {
		if mirrorView == nil {
			_setupMirrorView()
		}
	}

	func _setupMirrorView() {
		let mirrorView = FilteredMetalView(frame: self.frame)
		mirrorView.isUserInteractionEnabled = false
		mirrorView.isOpaque = true
		mirrorView.isPaused = false
		mirrorView.translatesAutoresizingMaskIntoConstraints = false
		mirrorView.transform = CGAffineTransform(scaleX: -1, y: 1)
		self.mirrorView = mirrorView

		self.superview!.insertSubview(mirrorView, aboveSubview: self)
		NSLayoutConstraint.deactivate(mirrorView.constraints)
		NSLayoutConstraint.activate([
			topAnchor.constraint(equalTo: mirrorView.topAnchor),
			leadingAnchor.constraint(equalTo: mirrorView.leadingAnchor),
			heightAnchor.constraint(equalTo: mirrorView.heightAnchor),
			widthAnchor.constraint(equalTo: mirrorView.widthAnchor),
		])

		renderer = MetalRenderer(mtkview: mirrorView, filter: .global)
		mirrorView.delegate = renderer

		updateDisplay()
	}

	func updateDisplay() {
		guard let renderer else { return }

		UIGraphicsBeginImageContextWithOptions(bounds.size, true, UIScreen.main.scale)

		layer.render(in: UIGraphicsGetCurrentContext()!)
		let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage

		UIGraphicsEndImageContext()

		let image = cgImage.map { CIImage(cgImage: $0) } ?? CIImage(color: .gray)
		renderer.render(image)
	}

	override var contentOffset: CGPoint {
		didSet {
			updateDisplay()
		}
	}

	override var frame: CGRect {
		didSet {
			updateDisplay()
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		DispatchQueue.main.async {
			self.updateDisplay()
		}
	}

}
