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
