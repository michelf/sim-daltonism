import UIKit

class SettingsViewController: UIViewController {

	@IBOutlet var paletteScrollView: MirroredScrollView?

	@IBOutlet var visionTypeName: UILabel?
	@IBOutlet var visionTypeDescription: UILabel?

	@IBOutlet var redStripeSwitch:  UISwitch!
	@IBOutlet var greenStripeSwitch:  UISwitch!
	@IBOutlet var blueStripeSwitch:  UISwitch!
	@IBOutlet var invertHueSwitch:  UISwitch!
	@IBOutlet var invertLuminanceSwitch:  UISwitch!
	@IBOutlet var saturationBoostSwitch:  UISwitch!

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

		// Vision Tools
		redStripeSwitch.isOn = FilterStore.global.configuration.stripeConfig.redStripes != 0
		greenStripeSwitch.isOn = FilterStore.global.configuration.stripeConfig.greenStripes != 0
		blueStripeSwitch.isOn = FilterStore.global.configuration.stripeConfig.blueStripes != 0
		invertHueSwitch.isOn = FilterStore.global.configuration.hueShift
		invertLuminanceSwitch.isOn = FilterStore.global.configuration.invertLuminance
		saturationBoostSwitch.isOn = FilterStore.global.configuration.colorBoost
	}

	@IBAction func closeSettings(_ sender: Any) {
		self.presentingViewController?.dismiss(animated: true)
	}


	@IBAction func redStripeSwitchToggled(_ sender: Any) {
		FilterStore.global.configuration.stripeConfig.redStripes = redStripeSwitch.isOn ? 2 : 0
	}

	@IBAction func greenStripeSwitchToggled(_ sender: Any) {
		FilterStore.global.configuration.stripeConfig.greenStripes = greenStripeSwitch.isOn ? 2 : 0
	}

	@IBAction func blueStripeSwitchToggled(_ sender: Any) {
		FilterStore.global.configuration.stripeConfig.blueStripes = blueStripeSwitch.isOn ? 2 : 0
	}

	@IBAction func invertHueSwitchToggled(_ sender: Any) {
		FilterStore.global.configuration.hueShift = invertHueSwitch.isOn
	}

	@IBAction func invertLuminanceSwitchToggled(_ sender: Any) {
		FilterStore.global.configuration.invertLuminance = invertLuminanceSwitch.isOn
	}

	@IBAction func saturationBoostSwitchToggled(_ sender: Any) {
		FilterStore.global.configuration.colorBoost = saturationBoostSwitch.isOn
	}

}
