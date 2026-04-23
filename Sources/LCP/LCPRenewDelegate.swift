//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import SafariServices

/// UX delegate for the loan renew LSD interaction.
public protocol LCPRenewDelegate {
    /// Called when the renew interaction allows to customize the end date programmatically.
    ///
    /// You can prompt the user for the number of days to renew, for example.
    /// The returned date should not exceed `maximumDate`.
    func preferredEndDate(maximum: Date?) async throws -> Date?

    /// Called when the renew interaction uses an HTML web page.
    ///
    /// You should present the URL in a `SFSafariViewController` and call the `completion` callback when the browser
    /// is dismissed by the user.
    func presentWebPage(url: HTTPURL) async throws
}

#if canImport(UIKit)
    import UIKit

    /// Default `LCPRenewDelegate` implementation using standard views.
    ///
    /// No date picker is presented for selecting a preferred end date. If you want to support one, you can subclass or
    /// decorate `LCPRenewDelegate`.
    public class LCPDefaultRenewDelegate: NSObject, LCPRenewDelegate {
        private let presentingViewController: UIViewController
        private let modalPresentationStyle: UIModalPresentationStyle

        public init(presentingViewController: UIViewController, modalPresentationStyle: UIModalPresentationStyle = .formSheet) {
            self.presentingViewController = presentingViewController
            self.modalPresentationStyle = modalPresentationStyle
        }

        public func preferredEndDate(maximum: Date?) async throws -> Date? {
            nil
        }

        @MainActor
        public func presentWebPage(url: HTTPURL) async throws {
            await withCheckedContinuation { continuation in
                webPageContinuation = continuation

                let safariVC = SFSafariViewController(url: url.url)
                safariVC.modalPresentationStyle = modalPresentationStyle
                safariVC.presentationController?.delegate = self
                safariVC.delegate = self
                presentingViewController.present(safariVC, animated: true)
            }
        }

        private var webPageContinuation: CheckedContinuation<Void, Never>?
    }

    extension LCPDefaultRenewDelegate: UIAdaptivePresentationControllerDelegate {
        public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            webPageContinuation?.resume(returning: ())
            webPageContinuation = nil
        }
    }

    extension LCPDefaultRenewDelegate: SFSafariViewControllerDelegate {
        public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            webPageContinuation?.resume(returning: ())
            webPageContinuation = nil
        }
    }
#endif

#if canImport(AppKit)
    import AppKit
    import WebKit

    /// Default `LCPRenewDelegate` implementation using standard AppKit views.
    ///
    /// No date picker is presented for selecting a preferred end date. If you want to support one, you
    /// can subclass or decorate `LCPRenewDelegate`.
    public class LCPDefaultRenewDelegate: NSObject, LCPRenewDelegate {
        private let parentWindow: NSWindow
        private let sheetSize: NSSize

        public init(parentWindow: NSWindow, sheetSize: NSSize = NSSize(width: 600, height: 480)) {
            self.parentWindow = parentWindow
            self.sheetSize = sheetSize
        }

        public func preferredEndDate(maximum: Date?) async throws -> Date? {
            nil
        }

        @MainActor
        public func presentWebPage(url: HTTPURL) async throws {
            await withCheckedContinuation { continuation in
                webPageContinuation = continuation

                let panel = NSPanel(
                    contentRect: NSRect(origin: .zero, size: sheetSize),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: true
                )
                panel.title = "Renew Loan"
                panel.isReleasedWhenClosed = false

                let webView = WKWebView(frame: panel.contentLayoutRect)
                webView.autoresizingMask = [.width, .height]
                webView.navigationDelegate = self
                webView.load(URLRequest(url: url.url))

                panel.contentView = webView
                currentPanel = panel

                parentWindow.beginSheet(panel) { [weak self] _ in
                    self?.dismissWebPage()
                }
            }
        }

        private var webPageContinuation: CheckedContinuation<Void, Never>?
        private var currentPanel: NSPanel?

        @MainActor
        private func dismissWebPage() {
            webPageContinuation?.resume(returning: ())
            webPageContinuation = nil
            currentPanel = nil
        }
    }

    extension LCPDefaultRenewDelegate: WKNavigationDelegate {
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard let panel = currentPanel else { return }
            parentWindow.endSheet(panel)
        }
    }

#endif
