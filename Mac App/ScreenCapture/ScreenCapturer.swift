
//    Copyright 2005-2021 Michel Fortin
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

import Foundation
import CoreImage

public protocol ScreenCapturer: AnyObject {
    var delegate: ScreenCaptureDelegate? { get set }
    func startSession(in frame: NSRect, delegate: ScreenCaptureDelegate) throws
    func stopSession()
}

public protocol ScreenCaptureDelegate: AnyObject {

    func didCaptureFrame(image: CIImage)
}


