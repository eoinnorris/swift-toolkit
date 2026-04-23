//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
#if canImport(UIKit)
import UIKit

/// An `LCPAuthenticating` implementation presenting a dialog to the user.
///
/// For this authentication to trigger, you must provide a `sender` parameter of type
/// `UIViewController` to `Streamer.open()` or `LCPService.retrieveLicense()`. It will be used
/// as the presenting view controller for the dialog.
public class LCPDialogAuthentication: LCPAuthenticating, Loggable {
    private let animated: Bool
    private let modalPresentationStyle: UIModalPresentationStyle
    private let modalTransitionStyle: UIModalTransitionStyle

    public init(animated: Bool = true, modalPresentationStyle: UIModalPresentationStyle = .formSheet, modalTransitionStyle: UIModalTransitionStyle = .coverVertical) {
        self.animated = animated
        self.modalPresentationStyle = modalPresentationStyle
        self.modalTransitionStyle = modalTransitionStyle
    }

    public func retrievePassphrase(
        for license: LCPAuthenticatedLicense,
        reason: LCPAuthenticationReason,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> String? {
        guard allowUserInteraction, let viewController = sender as? UIViewController else {
            if !(sender is UIViewController) {
                log(.error, "Tried to present the LCP dialog without providing a `UIViewController` as `sender`")
            }
            return nil
        }

        return await withCheckedContinuation { continuation in
            let dialogViewController = LCPDialogViewController(license: license, reason: reason) { passphrase in
                continuation.resume(returning: passphrase)
            }

            dialogViewController.modalPresentationStyle = modalPresentationStyle
            dialogViewController.modalTransitionStyle = modalTransitionStyle

            viewController.present(dialogViewController, animated: animated)
        }
    }
}
#endif


#if canImport(AppKit)

import AppKit

public class LCPDialogAuthentication: LCPAuthenticating, Loggable {
    private let animated: Bool

    public init(animated: Bool = true) {
        self.animated = animated
    }

    public func retrievePassphrase(
        for license: LCPAuthenticatedLicense,
        reason: LCPAuthenticationReason,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> String? {
        guard allowUserInteraction else { return nil }

        // On macOS the sender should be an NSWindow (or NSViewController from which you grab the window)
        let window: NSWindow? = {
            if let w = sender as? NSWindow { return w }
            if let vc = sender as? NSViewController { return vc.view.window }
            return nil
        }()

        guard let parentWindow = window else {
            log(.error, "Tried to present the LCP dialog without providing an NSWindow or NSViewController as `sender`")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let dialogViewController = LCPDialogViewController(license: license, reason: reason) { passphrase in
                parentWindow.endSheet(parentWindow.attachedSheet!)
                continuation.resume(returning: passphrase!)
            }

            let sheetWindow = NSWindow(contentViewController: dialogViewController)
            sheetWindow.styleMask = [.titled]

            parentWindow.beginSheet(sheetWindow, completionHandler: nil)
        }
    }
}
#endif
