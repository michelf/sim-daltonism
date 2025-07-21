
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

import Foundation
import CoreImage
#if os(macOS)
import AppKit
#endif

@MainActor
public protocol CaptureStream: AnyObject {
//    var delegate: CaptureStreamDelegate? { get set }
    func startSession(in frame: CGRect) throws
    func stopSession()
	func checkCapturePermission() -> Bool
#if os(macOS)
	func handleMouseEvent(_ event: NSEvent)
#endif
}

nonisolated public protocol CaptureStreamDelegate: AnyObject, Sendable {

    func didCaptureFrame(image: CIImage)
	func currentRenderedImage() -> CIImage

}


