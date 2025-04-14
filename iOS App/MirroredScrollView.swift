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
		mirrorView.isHidden = false
		mirrorView.backgroundColor = .purple
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
