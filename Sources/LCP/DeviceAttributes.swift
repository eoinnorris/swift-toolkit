//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation


#if canImport(UIKit)
import UIKit

public struct DeviceAttributes: Codable {

    public static var name: String {
        UIDevice.current.name
    }

    public static func deviceOpen(url: URL) {
        UIApplication.shared.open(url)
    }
}

#elseif canImport(AppKit)
import AppKit
import SystemConfiguration

public struct DeviceAttributes: Codable {

    public static var name: String {
        let name = SCDynamicStoreCopyComputerName(nil, nil) as String?
        return name ?? "Mac"
    }

    public static func deviceOpen(url: URL) {
        NSWorkspace.shared.open(url)
    }
}

#endif
