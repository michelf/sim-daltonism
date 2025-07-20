import Foundation

public struct FilterConfiguration: Sendable {
	public var vision: VisionType = .normal
	public var simulation: Simulation = .machadoEtAl

	public var stripeConfig = StripeConfig()
	public var invertLuminance: Bool = false
	public var hueShift: Bool = false
	public var colorBoost: Bool = false

	var isUnalteredNormalVision: Bool {
		return vision == .normal && stripeConfig.isPassthrough && !invertLuminance && !hueShift && !colorBoost
	}
}

extension FilterConfiguration {

	public mutating func read(from defaults: UserDefaults, prefix: String = "") {
		vision = VisionType(rawValue: UserDefaults.standard.integer(forKey: FilterConfiguration.visionKey)) ?? vision
		simulation = Simulation(rawValue: UserDefaults.standard.integer(forKey: FilterConfiguration.simulationKey)) ?? simulation

		stripeConfig.redStripes = UserDefaults.standard.float(forKey: FilterConfiguration.redStripesKey)
		stripeConfig.greenStripes = UserDefaults.standard.float(forKey: FilterConfiguration.greenStripesKey)
		stripeConfig.blueStripes = UserDefaults.standard.float(forKey: FilterConfiguration.blueStripesKey)

		invertLuminance = UserDefaults.standard.bool(forKey: FilterConfiguration.invertLuminanceKey)
		hueShift = UserDefaults.standard.bool(forKey: FilterConfiguration.hueShiftKey)
		colorBoost = UserDefaults.standard.bool(forKey: FilterConfiguration.colorBoostKey)
	}

	public func write(to defaults: UserDefaults, prefix: String = "") {
		defaults.set(vision.rawValue, forKey: FilterConfiguration.visionKey)
		defaults.set(simulation.rawValue, forKey: FilterConfiguration.simulationKey)

		defaults.set(stripeConfig.redStripes, forKey: FilterConfiguration.redStripesKey)
		defaults.set(stripeConfig.greenStripes, forKey: FilterConfiguration.greenStripesKey)
		defaults.set(stripeConfig.blueStripes, forKey: FilterConfiguration.blueStripesKey)

		defaults.set(invertLuminance, forKey: FilterConfiguration.invertLuminanceKey)
		defaults.set(hueShift, forKey: FilterConfiguration.hueShiftKey)
		defaults.set(colorBoost, forKey: FilterConfiguration.colorBoostKey)
	}

	private static let visionKey = "VisionType"
	private static let simulationKey = "SimulationKey"

	private static let redStripesKey = "RedStripes"
	private static let greenStripesKey = "GreenStripes"
	private static let blueStripesKey = "BlueStripes"

	private static let invertLuminanceKey = "InvertLuminance"
	private static let hueShiftKey = "HueShift"
	private static let colorBoostKey = "ColorBoost"

}
