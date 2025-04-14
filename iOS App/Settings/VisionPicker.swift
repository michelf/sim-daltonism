import UIKit

class VisionPicker: UITableViewController {

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		NotificationCenter.default.addObserver(self, selector: #selector(updateConfiguration), name: FilterStore.didChangeNotification, object: nil)

		DispatchQueue.main.async {
			self.scrollCurrentChoiceToVisible()
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		NotificationCenter.default.removeObserver(self)
	}

	@objc func updateConfiguration() {
		tableView.reloadData()
	}

	func scrollCurrentChoiceToVisible() {
		let currentVisionType = FilterStore.global.configuration.vision

		guard let tableView = self.tableView else { return }
		let sectionCount = tableView.numberOfSections
		for section in 0..<sectionCount {
			let rowCount = tableView.numberOfRows(inSection: section)
			for row in 0..<rowCount {
				let indexPath = IndexPath(row:row, section: section)
				if self.tableView(tableView, cellForRowAt: indexPath).tag == currentVisionType.rawValue {
					let sectionIndexPath = IndexPath(row: rowCount-1, section: section)
					tableView.scrollToRow(at: sectionIndexPath, at: .bottom, animated: false)
					return
				}
			}
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = super.tableView(tableView, cellForRowAt: indexPath)

		let currentVisionType = FilterStore.global.configuration.vision
		if cell.tag == currentVisionType.rawValue {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let cell = tableView.cellForRow(at: indexPath) else { return }
		let currentVisionType = cell.tag
		FilterStore.global.configuration.vision = VisionType(rawValue: currentVisionType) ?? .normal

		// Move the checkmark before animation
		for cell in tableView.visibleCells {
			if cell.tag == currentVisionType {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}
		}

		tableView.deselectRow(at: indexPath, animated: true)
		navigationController?.popViewController(animated: true)
	}


}
