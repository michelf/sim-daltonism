import UIKit

class MirroredScrollView: UIScrollView {

	private var mirrorView: OpenGLPixelBufferView?

	override func didMoveToWindow() {
		if mirrorView == nil {
			_setupMirrorView()
		}
	}

	func _setupMirrorView() {
		let mirrorView = OpenGLPixelBufferView(frame: self.frame)
		mirrorView.isUserInteractionEnabled = false
		mirrorView.isOpaque = true
		mirrorView.translatesAutoresizingMaskIntoConstraints = false
		mirrorView.transform = CGAffineTransform(scaleX: -1, y: 1)
		self.mirrorView = mirrorView

		self.superview?.insertSubview(mirrorView, aboveSubview: self)
		NSLayoutConstraint.deactivate(mirrorView.constraints)
		NSLayoutConstraint.activate([
			topAnchor.constraint(equalTo: mirrorView.topAnchor),
			leadingAnchor.constraint(equalTo: mirrorView.leadingAnchor),
			heightAnchor.constraint(equalTo: mirrorView.heightAnchor),
			widthAnchor.constraint(equalTo: mirrorView.widthAnchor),
		])

		mirrorView.displayContent(self)
	}

	func updateDisplay() {
		mirrorView?.displayContent(self)
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
