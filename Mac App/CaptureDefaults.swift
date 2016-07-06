
//	Copyright 2005-2016 Michel Fortin
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.

import Foundation

enum RefreshSpeed: Int {
	case slow = -1
	case normal = 0
	case fast = 1

	var image: NSImage {
		switch self {
		case .slow: return NSImage(named: "SlowFrameRateTemplate")!
		case .normal: return NSImage(named: "NormalFrameRateTemplate")!
		case .fast: return NSImage(named: "FastFrameRateTemplate")!
		}
	}

	var updateInterval: TimeInterval {
		switch self {
		case .slow:   return 0.1
		case .normal: return 0.05
		case .fast:   return 0.02
		}
	}
}

var refreshSpeedDefault: RefreshSpeed {
	get {
		return RefreshSpeed(rawValue: UserDefaults.standard.integer(forKey: "RefreshSpeed")) ?? .normal
	}
	set (speed) {
		UserDefaults.standard.set(speed.rawValue, forKey: "RefreshSpeed")
	}
}

enum ViewArea: Int {
	case underWindow = 0
	case mousePointer = 1

	var image: NSImage {
		switch self {
		case .underWindow: return NSImage(named: "FilteredTransparencyTemplate")!
		case .mousePointer: return NSImage(named: "FilteredMouseAreaTemplate")!
		}
	}
}

var viewAreaDefault: ViewArea {
	get {
		return ViewArea(rawValue: UserDefaults.standard.integer(forKey: "ViewArea")) ?? .underWindow
	}
	set (area) {
		UserDefaults.standard.set(area.rawValue, forKey: "ViewArea")
	}
}

