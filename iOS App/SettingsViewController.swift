import UIKit

class SettingsViewController: UIViewController {

	@IBOutlet var paletteScrollView: MirroredScrollView?

	@IBOutlet var visionTypeName: UILabel?
	@IBOutlet var visionTypeDescription: UILabel?

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	override var automaticallyAdjustsScrollViewInsets: Bool {
		get { return false }
		set {}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		self.paletteScrollView?.subviews.first?.transform = CGAffineTransform(scaleX: -1, y: 1)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.readConfiguration()
		NotificationCenter.default.addObserver(self, selector: #selector(readConfiguration), name: FilterStore.didChangeNotification, object: FilterStore.global)
	}

	func viewWillDisappear(animated: Bool) {
		NotificationCenter.default.removeObserver(self)
		super.viewWillDisappear(animated)
	}

	@objc func readConfiguration() {
		DispatchQueue.main.async {
			self.paletteScrollView?.updateDisplay()
		}

		// Sim Daltonism
		self.visionTypeName!.text = FilterStore.global.configuration.vision.name
		self.visionTypeDescription!.text = FilterStore.global.configuration.vision.description
	}

	@IBAction func closeSettings(_ sender: Any) {
		self.presentingViewController?.dismiss(animated: true)
	}

}
