
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
import AppKit

enum FilterWindowAppearance: Int {
	case systemDefault
	case systemReversed
	case light
	case dark

	var prescribedAppearance: NSAppearance? {
		guard #available(macOS 10.14, *) else { return nil }
		let newAppearanceName: NSAppearance.Name
		switch self {
		case .systemDefault:
			return nil
		case .systemReversed:
			newAppearanceName = switch NSApplication.shared.effectiveAppearance.name {
			case .aqua: .darkAqua
			case .darkAqua: .aqua
			case .accessibilityHighContrastAqua: .accessibilityHighContrastDarkAqua
			case .vibrantDark: .vibrantLight
			case .vibrantLight: .vibrantDark
			case .accessibilityHighContrastVibrantDark: .accessibilityHighContrastVibrantLight
			case .accessibilityHighContrastVibrantLight: .accessibilityHighContrastVibrantDark
			default: .aqua
			}
		case .light:
			newAppearanceName = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .accessibilityHighContrastAqua]) ?? .aqua
		case .dark:
			newAppearanceName = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .accessibilityHighContrastDarkAqua]) ?? .darkAqua
		}
		return NSAppearance(named: newAppearanceName)
	}
}

extension UserDefaults {

	var filterWindowAppearance: FilterWindowAppearance {
		let intAppearance = UserDefaults.standard.integer(forKey: "FilterWindowAppearance")
		return FilterWindowAppearance(rawValue: intAppearance) ?? .systemDefault
	}

}
