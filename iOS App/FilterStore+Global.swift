
extension FilterStore {

	/// A filter store with a configuration synchronized with user defaults.
	static let global: FilterStore = {
		var config = FilterConfiguration()
		config.read(from: .standard)
		return GlobalFilterStore(configuration: config)
	}()

}

class GlobalFilterStore: FilterStore {

	override var configuration: FilterConfiguration {
		didSet {
			configuration.write(to: .standard)
		}
	}

}
