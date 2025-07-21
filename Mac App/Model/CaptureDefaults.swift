
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

import AppKit

enum RefreshSpeed: Int {
	case slow = -1
	case normal = 0
	case fast = 1
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
}

var viewAreaDefault: ViewArea {
	get {
		return ViewArea(rawValue: UserDefaults.standard.integer(forKey: "ViewArea")) ?? .underWindow
	}
	set (area) {
		UserDefaults.standard.set(area.rawValue, forKey: "ViewArea")
	}
}

