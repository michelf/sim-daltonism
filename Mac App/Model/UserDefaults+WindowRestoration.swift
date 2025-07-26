
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

import Foundation

public extension UserDefaults {

	static let visionKey = "SimVisionType"
	static let simulationKey = "SimulationKey"

	static var vision: VisionType {
		get {
			let value = UserDefaults.standard.integer(forKey: UserDefaults.visionKey)
			return VisionType(rawValue: value) ?? .defaultValue
		}
		set (vision) {
			UserDefaults.standard.set(vision.rawValue, forKey: UserDefaults.visionKey)
		}
	}

	static var simulation: Simulation {
		get {
			let value = UserDefaults.standard.integer(forKey: UserDefaults.simulationKey)
			return Simulation(rawValue: value) ?? .defaultValue
		}
		set (simulation) {
			UserDefaults.standard.set(simulation.rawValue, forKey: UserDefaults.simulationKey)
		}
    }

}

enum WindowRestoration {

    static let visionKey = "VisionType"
	static let simulationKey = "SimulationKey"

    static func encodeRestorable(state: NSCoder, _ vision: VisionType, _ sim: Simulation) {
		state.encode(vision.rawValue, forKey: Self.visionKey)
		state.encode(sim.rawValue, forKey: Self.simulationKey)
    }

    static func decodeRestorable(state: NSCoder) -> (VisionType, Simulation) {
        let vision = state.decodeInteger(forKey: Self.visionKey)
        let sim = state.decodeInteger(forKey: Self.simulationKey)
        return (VisionType(rawValue: vision) ?? .defaultValue,
				Simulation(rawValue: sim) ?? .defaultValue)
    }

}
