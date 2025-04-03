
class VisionPicker: UITableViewController {

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		NotificationCenter.default.addObserver(self, selector: #selector(updateDefaults), name: UserDefaults.didChangeNotification, object: nil)

		DispatchQueue.main.async {
			self.scrollCurrentChoiceToVisible()
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		NotificationCenter.default.removeObserver(self)
	}

	@objc func updateDefaults() {
		tableView.reloadData()
	}

	func scrollCurrentChoiceToVisible() {
		let currentVisionType = UserDefaults.standard.integer(forKey: SimVisionTypeKey)

		guard let tableView = self.tableView else { return }
		let sectionCount = tableView.numberOfSections
		for section in 0..<sectionCount {
			let rowCount = tableView.numberOfRows(inSection: section)
			for row in 0..<rowCount {
				let indexPath = IndexPath(row:row, section: section)
				if self.tableView(tableView, cellForRowAt: indexPath).tag == currentVisionType {
					let sectionIndexPath = IndexPath(row: rowCount-1, section: section)
					tableView.scrollToRow(at: sectionIndexPath, at: .bottom, animated: false)
					return
				}
			}
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = super.tableView(tableView, cellForRowAt: indexPath)

		let currentVisionType = UserDefaults.standard.integer(forKey: SimVisionTypeKey)
		if cell.tag == currentVisionType {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let cell = tableView.cellForRow(at: indexPath) else { return }
		let currentVisionType = cell.tag
		UserDefaults.standard.set(currentVisionType, forKey:SimVisionTypeKey)

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
