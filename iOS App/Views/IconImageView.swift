
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

import UIKit

class IconImageView: UIImageView {

	override func awakeFromNib() {
		super.awakeFromNib()
		self.layer.cornerRadius = 14
		if #available(iOS 13.0, *) {
			self.layer.cornerCurve = .continuous
		}
		self.layer.masksToBounds = true
	}
	
}
