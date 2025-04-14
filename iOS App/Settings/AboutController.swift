import UIKit

class AboutController: UITableViewController {

	@IBOutlet var websiteCell: UITableViewCell?
	@IBOutlet var feedbackCell: UITableViewCell?
	@IBOutlet var appStoreCell: UITableViewCell?
	@IBOutlet var redStripeCell: UITableViewCell?

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
		case redStripeCell:
			UIApplication.shared.open(URL(string: "https://itunes.apple.com/us/app/red-stripe/id997446505?ls=1&mt=8")!)
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
