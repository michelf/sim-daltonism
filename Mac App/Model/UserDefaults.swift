
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

fileprivate extension UserDefaults {
    static let VisionKey = "SimVisionType"
    static let SimulationKey = "SimulationKey"
}

public extension UserDefaults {
    static func getVision() -> Int {
        UserDefaults.standard.integer(forKey: UserDefaults.VisionKey)
    }

    static func getSimulation() -> Int {
        UserDefaults.standard.integer(forKey: UserDefaults.SimulationKey)
    }

    static func setVision(_ vision: Int) {
        UserDefaults.standard.set(vision, forKey: UserDefaults.VisionKey)
    }

    static func setSimulation(_ simulation: Int) {
        UserDefaults.standard.set(simulation, forKey: UserDefaults.SimulationKey)
    }
}
