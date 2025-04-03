
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
		self.readDefaults()
		NotificationCenter.default.addObserver(self, selector: #selector(readDefaults), name: UserDefaults.didChangeNotification, object: nil)
	}

	func viewWillDisappear(animated: Bool) {
		NotificationCenter.default.removeObserver(self)
		super.viewWillDisappear(animated)
	}

	@objc func readDefaults() {
		let userDefaults = UserDefaults.standard

		DispatchQueue.main.async {
			self.paletteScrollView?.updateDisplay()
		}

		// Sim Daltonism
		let visionType = userDefaults.integer(forKey: SimVisionTypeKey)
		self.visionTypeName!.text = SimVisionTypeName(visionType)
		self.visionTypeDescription!.text = SimVisionTypeDesc(visionType)
	}

	@IBAction func closeSettings(_ sender: Any) {
		self.presentingViewController?.dismiss(animated: true)
	}

}
