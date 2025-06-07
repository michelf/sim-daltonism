
//    Copyright 2005-2021 Michel Fortin
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

import Foundation

public extension UserDefaults {

    static func getVision() -> VisionType {
        let value = UserDefaults.standard.integer(forKey: UserDefaults.VisionKey)
		return VisionType(rawValue: value) ?? .defaultValue
    }

    static func getSimulation() -> Simulation {
        let value = UserDefaults.standard.integer(forKey: UserDefaults.SimulationKey)
		return Simulation(rawValue: value) ?? .defaultValue
    }

    static func setVision(_ vision: VisionType) {
		UserDefaults.standard.set(vision.rawValue, forKey: UserDefaults.VisionKey)
    }

    static func setSimulation(_ simulation: Simulation) {
		UserDefaults.standard.set(simulation.rawValue, forKey: UserDefaults.SimulationKey)
    }

}

enum WindowRestoration {

    static let VisionKey = "VisionType"
    static let SimulationKey = "SimulationKey"

    static func encodeRestorable(state: NSCoder, _ vision: VisionType, _ sim: Simulation) {
		state.encode(vision.rawValue, forKey: Self.VisionKey)
		state.encode(sim.rawValue, forKey: Self.SimulationKey)
    }

    static func decodeRestorable(state: NSCoder) -> (VisionType, Simulation) {
        let vision = state.decodeInteger(forKey: Self.VisionKey)
        let sim = state.decodeInteger(forKey: Self.SimulationKey)
        return (VisionType(rawValue: vision) ?? .defaultValue,
				Simulation(rawValue: sim) ?? .defaultValue)
    }

}

// MARK: - Data Transfer Utilities

fileprivate extension UserDefaults {
    static let VisionKey = "SimVisionType"
    static let SimulationKey = "SimulationKey"
}
