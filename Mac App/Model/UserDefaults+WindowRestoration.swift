
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
import AppKit

public extension UserDefaults {

    static func getVision() -> VisionType {
        let value = UserDefaults.standard.integer(forKey: UserDefaults.VisionKey)
        return VisionTypeDTO(fromUserDefaults: value).model
    }

    static func getSimulation() -> Simulation {
        let value = UserDefaults.standard.integer(forKey: UserDefaults.SimulationKey)
        return SimulationDTO(fromUserDefaults: value).model
    }

    static func setVision(_ vision: VisionType) {
        let dto = VisionTypeDTO(fromVision: vision)
        UserDefaults.standard.set(dto.userDefaultsValue, forKey: UserDefaults.VisionKey)
    }

    static func setSimulation(_ simulation: Simulation) {
        let dto = SimulationDTO(fromSimulation: simulation)
        UserDefaults.standard.set(dto.userDefaultsValue, forKey: UserDefaults.SimulationKey)
    }

}

enum WindowRestoration {

    static let VisionKey = "VisionType"
    static let SimulationKey = "SimulationKey"

    static func encodeRestorable(state: NSCoder, _ vision: VisionType, _ sim: Simulation) {
        let encodedVision = Self.encode(vision)
        let encodedSimulation = Self.encode(sim)
        state.encode(encodedVision, forKey: Self.VisionKey)
        state.encode(encodedSimulation, forKey: Self.SimulationKey)
    }

    static func decodeRestorable(state: NSCoder) -> (VisionType, Simulation) {
        let vision = state.decodeInteger(forKey: Self.VisionKey)
        let sim = state.decodeInteger(forKey: Self.SimulationKey)
        return (Self.restore(vision: vision), Self.restore(simulation: sim))
    }

    private static func restore(vision state: Int) -> VisionType {
        VisionTypeDTO(fromWindowState: state).model
    }

    private static func restore(simulation state: Int) -> Simulation {
        SimulationDTO(fromWindowState: state).model
    }

    private static func encode(_ vision: VisionType) -> Int {
        VisionTypeDTO(fromVision: vision).windowStateValue
    }

    private static func encode(_ simulation: Simulation) -> Int {
        SimulationDTO(fromSimulation: simulation).windowStateValue
    }
}

// MARK: - Data Transfer Utilities

fileprivate extension UserDefaults {
    static let VisionKey = "SimVisionType"
    static let SimulationKey = "SimulationKey"
}

fileprivate enum SimulationDTO: Int {
    case wicklineHCIRN
    case machadoEtAl

    var userDefaultsValue: Int { rawValue }
    var windowStateValue: Int { rawValue }

    init(fromUserDefaults value: Int) {
        self = .init(rawValue: value) ?? .wicklineHCIRN
    }

    init(fromWindowState value: Int) {
        self.init(fromUserDefaults: value)
    }

    init(fromSimulation sim: Simulation) {
        switch sim {
            case .wicklineHCIRN: self = .wicklineHCIRN
            case .machadoEtAl:   self = .machadoEtAl
        }
    }

    var model: Simulation {
        switch self {
            case .wicklineHCIRN: return .wicklineHCIRN
            case .machadoEtAl:   return .machadoEtAl
        }
    }
}

fileprivate enum VisionTypeDTO: Int {
    case normal
    case deutan
    case deuteranomaly
    case protan
    case protanomaly
    case tritan
    case tritanomaly
    case monochromat
    case monochromacyPartial

    var userDefaultsValue: Int { rawValue }
    var windowStateValue: Int { rawValue }

    init(fromUserDefaults value: Int) {
        self = .init(rawValue: value) ?? .normal
    }

    init(fromWindowState value: Int) {
        self.init(fromUserDefaults: value)
    }

    init(fromVision type: VisionType) {
        switch type {
            case .normal:               self = .normal
            case .deutan:               self = .deutan
            case .deuteranomaly:        self = .deuteranomaly
            case .protan:               self = .protan
            case .protanomaly:          self = .protanomaly
            case .tritan:               self = .tritan
            case .tritanomaly:          self = .tritanomaly
            case .monochromat:          self = .monochromat
            case .monochromacyPartial:  self = .monochromacyPartial
        }
    }

    var model: VisionType {
        switch self {
            case .normal:               return .normal
            case .deutan:               return .deutan
            case .deuteranomaly:        return .deuteranomaly
            case .protan:               return .protan
            case .protanomaly:          return .protanomaly
            case .tritan:               return .tritan
            case .tritanomaly:          return .tritanomaly
            case .monochromat:          return .monochromat
            case .monochromacyPartial:  return .monochromacyPartial
        }
    }
}
