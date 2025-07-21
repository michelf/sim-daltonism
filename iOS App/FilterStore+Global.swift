
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
