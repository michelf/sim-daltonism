
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

import CoreImage
import CoreGraphics
import UniformTypeIdentifiers

extension CIImage {

	func convertToCGImage() -> CGImage? {
		let context = CIContext(options: [.useSoftwareRenderer: false])
		return context.createCGImage(self, from: self.extent)
	}

	@discardableResult func writePNG(to destinationURL: URL, scale: CGFloat) -> Bool {
#if os(macOS)
		let pngTypeIdentifier = kUTTypePNG as CFString
#else
		let pngTypeIdentifier = UTType.png.identifier as CFString
#endif
		guard let image = convertToCGImage(),
			  let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, pngTypeIdentifier, 1, nil)
		else {
			return false
		}

		let dpi = scale * 72.0
		let options: [CFString: Any] = [
			kCGImagePropertyPixelWidth: image.width,
			kCGImagePropertyPixelHeight: image.height,
			kCGImagePropertyDPIWidth: dpi,
			kCGImagePropertyDPIHeight: dpi,
		]

		CGImageDestinationAddImage(destination, image, options as CFDictionary)
		let result = CGImageDestinationFinalize(destination)
		if result {
			// add "screenshot" extended attribute to file so QuickLook will display it at specified scale
			if let truePlist = try? PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0) {
				destinationURL.setExtendedAttribute(data: truePlist, forName: "com.apple.metadata:kMDItemIsScreenCapture")
			}
		}
		return result
	}

}

struct ImageExport {
	var name: String
	var image: CIImage
	var scale: CGFloat

	static let exportDirURL = FileManager.default.temporaryDirectory
		.appendingPathComponent("image-export", isDirectory: true)

	func exportPNG() -> URL? {
		assert(!name.isEmpty)
		let imageDirURL = Self.exportDirURL
			.appendingPathComponent("\(Int.random(in: 99...99999))")
		let imgURL = imageDirURL
			.appendingPathComponent(name, isDirectory: false)
			.appendingPathExtension("png")
		try! FileManager.default.createDirectory(at: imageDirURL, withIntermediateDirectories: true)
		if image.writePNG(to: imgURL, scale: scale) {
			return imgURL
		} else {
			return nil
		}
	}

	static func clearExportedImages() {
		try? FileManager.default.removeItem(at: Self.exportDirURL)
	}

}

extension URL {

	@discardableResult
	fileprivate func setExtendedAttribute(data: Data, forName name: String) -> Bool {
		self.withUnsafeFileSystemRepresentation { fileSystemPath in
			let result = data.withUnsafeBytes {
				setxattr(fileSystemPath, name, $0.baseAddress, data.count, 0, 0)
			}
			return result >= 0
		}
	}

}
