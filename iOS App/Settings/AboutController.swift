
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

class AboutController: UITableViewController {

	@IBOutlet var websiteCell: UITableViewCell?
	@IBOutlet var feedbackCell: UITableViewCell?
	@IBOutlet var appStoreCell: UITableViewCell?

	@IBOutlet var aboutCell: UITableViewCell?
	let aboutIndexPath: IndexPath = [1, 0]

	@IBOutlet var creditsCell: UITableViewCell?
	let creditsIndexPath: IndexPath = [3, 0]

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		let cell = tableView.cellForRow(at: indexPath)
		switch cell {
		case websiteCell:
			UIApplication.shared.open(Self.localizedWebsiteURL)
		case feedbackCell:
			UIApplication.shared.open(URL(string: "mailto:\(Self.localizedFeedbackEmailAddress)")!)
		case appStoreCell:
			UIApplication.shared.open(URL(string: "https://itunes.apple.com/us/app/sim-daltonism/id1050503579?ls=1&mt=8&action=viewContentsUserReviews")!)
		default:
			break
		}
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		switch indexPath {
		case aboutIndexPath:
			let availableSize = CGSizeMake(tableView.bounds.size.width, 100000)
			return aboutCell?.sizeThatFits(availableSize).height ?? tableView.rowHeight
		case aboutIndexPath:
			let availableSize = CGSizeMake(tableView.bounds.size.width, 100000)
			return creditsCell?.sizeThatFits(availableSize).height ?? tableView.rowHeight
		default:
			return super.tableView(tableView, heightForRowAt: indexPath)
		}
	}

	static let localizedWebsiteURL = URL(string: NSLocalizedString("https://michelf.ca/projects/sim-daltonism/", tableName: "URLs", comment: "Sim Daltonism website URL"))!

	static let localizedFeedbackEmailAddress = NSLocalizedString("sim-daltonism@michelf.ca", tableName: "URLs", comment: "Sim Daltonism feedback email");

}
