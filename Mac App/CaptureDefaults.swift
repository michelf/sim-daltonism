
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
	case Slow = -1
	case Normal = 0
	case Fast = 1

	var image: NSImage {
		switch self {
		case .Slow: return NSImage(named: "SlowFrameRateTemplate")!
		case .Normal: return NSImage(named: "NormalFrameRateTemplate")!
		case .Fast: return NSImage(named: "FastFrameRateTemplate")!
		}
	}

	var updateInterval: NSTimeInterval {
		switch self {
		case .Slow:   return 0.1
		case .Normal: return 0.05
		case .Fast:   return 0.02
		}
	}
}

var refreshSpeedDefault: RefreshSpeed {
	get {
		return RefreshSpeed(rawValue: NSUserDefaults.standardUserDefaults().integerForKey("RefreshSpeed")) ?? .Normal
	}
	set (speed) {
		NSUserDefaults.standardUserDefaults().setInteger(speed.rawValue, forKey: "RefreshSpeed")
	}
}

enum ViewArea: Int {
	case UnderWindow = 0
	case MousePointer = 1

	var image: NSImage {
		switch self {
		case .UnderWindow: return NSImage(named: "FilteredTransparencyTemplate")!
		case .MousePointer: return NSImage(named: "FilteredMouseAreaTemplate")!
		}
	}
}

var viewAreaDefault: ViewArea {
	get {
		return ViewArea(rawValue: NSUserDefaults.standardUserDefaults().integerForKey("ViewArea")) ?? .UnderWindow
	}
	set (area) {
		NSUserDefaults.standardUserDefaults().setInteger(area.rawValue, forKey: "ViewArea")
	}
}

