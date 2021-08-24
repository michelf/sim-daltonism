
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

extension NSError {
    
    convenience init(
        code: Int,
        localizedDescription: String,
        localizedFailureReason: String?,
        localizedRecoverySuggestion: String?,
        alertHelpButton: String?
    ) {
        self.init(domain: "simDaltonism", code: code, userInfo: [
            NSLocalizedDescriptionKey : localizedDescription,
            NSLocalizedFailureReasonErrorKey : localizedFailureReason ?? "",
            NSLocalizedRecoverySuggestionErrorKey : localizedRecoverySuggestion ?? "",
            NSHelpAnchorErrorKey : alertHelpButton ?? ""
        ])
    }
}

let MetalUnsupportedError = NSError(
    code: 0,
    localizedDescription: NSLocalizedString("MetalNotSupported", tableName: "Alerts", comment: ""),
    localizedFailureReason: NSLocalizedString("MetalNotSupportedMessage", tableName: "Alerts", comment: ""),
    localizedRecoverySuggestion: nil,
    alertHelpButton: nil
) as Error

let MetalRendererError = NSError(
    code: 1,
    localizedDescription: NSLocalizedString("MetalFailure", tableName: "Alerts", comment: ""),
    localizedFailureReason: NSLocalizedString("MetalFailureMessage", tableName: "Alerts", comment: ""),
    localizedRecoverySuggestion: nil,
    alertHelpButton: nil
) as Error
