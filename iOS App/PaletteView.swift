import UIKit

private let numColumns = colors.count
private let numRows = whiteBlackEffect.count

private let colors = [
	(r: 0.0, g: 0.0, b: 0.9),
	(r: 0.8, g: 0.0, b: 1.0),
	(r: 1.0, g: 0.0, b: 0.0),
	(r: 1.0, g: 0.63, b: 0.0),
	(r: 1.0, g: 0.94, b: 0.0),
	(r: 0.7, g: 1.0, b: 0.0),
	(r: 0.0, g: 1.0, b: 0.0),
	(r: 0.0, g: 0.8, b: 1.0),
]
private let whiteBlackEffect = [
	(w: 0.3, b: 1.0),
	(w: 0.5, b: 1.0),
	(w: 0.7, b: 1.0),
	(w: 0.9, b: 1.0),
	(w: 1.0, b: 1.0), // middle
	(w: 1.0, b: 0.63),
	(w: 1.0, b: 0.4),
	(w: 1.0, b: 0.2),
]
private let margin: CGFloat = 2.0

class PaletteView: UIView {
	var _colorViews: [UIView] = []

	func colorFor(row: Int, column: Int) -> UIColor {
		var red   = colors[column].r
		var green = colors[column].g
		var blue  = colors[column].b

		red   *= whiteBlackEffect[row].w
		green *= whiteBlackEffect[row].w
		blue  *= whiteBlackEffect[row].w

		red   = 1.0 - ((1.0 - red)   * whiteBlackEffect[row].b)
		green = 1.0 - ((1.0 - green) * whiteBlackEffect[row].b)
		blue  = 1.0 - ((1.0 - blue)  * whiteBlackEffect[row].b)

		return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
	}

	func _recolorViews() {
		for column in 0..<numColumns{
			for row in 0..<numRows {
				let viewIndex = row + column*numRows
				guard _colorViews.indices.contains(viewIndex) else { return }
				_colorViews[viewIndex].backgroundColor = colorFor(row: row, column:column)
				UIView.transition(from: _colorViews[viewIndex], to:_colorViews[viewIndex], duration:0.1, options: [.transitionFlipFromTop, .showHideTransitionViews])
			}
		}
	}

	override func layoutSubviews() {
		let bounds = self.bounds;
		var colorRect = CGRect(x: margin,
							   y: margin,
							   width: max(margin, floor((bounds.size.width - margin) / CGFloat(numColumns)) - 2*margin),
							   height: max(margin, floor((bounds.size.height - margin) / CGFloat(numRows)) - 2*margin))
		colorRect.origin.x = round((bounds.size.width - (colorRect.size.width + margin) * CGFloat(numColumns)) / 2)

		for column in 0..<numColumns {
			var localRect = colorRect
			for row in 0..<numRows {
				let viewIndex = row + column*numRows
				if !_colorViews.indices.contains(viewIndex) {
					_colorViews.insert(UIView(), at: viewIndex)
					_colorViews[viewIndex].layer.cornerRadius = 6
					addSubview(_colorViews[viewIndex])
				}

				_colorViews[viewIndex].frame = localRect
				_colorViews[viewIndex].backgroundColor = colorFor(row: row, column: column)

				localRect.origin.y += colorRect.size.height + margin
			}
			colorRect.origin.x += colorRect.size.width + margin
		}

		DispatchQueue.main.async {
			self._recolorViews()
		}
	}

}
