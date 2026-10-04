//
//  MailExtension.swift
//  MailCorrectorExtension
//
//  The MailKit entry point. Provides a compose session handler that offers a
//  proofreading view controller in the Mail compose window.
//

import Foundation
import MailKit

/// The principal object for the Mail extension.
///
/// Referenced by `NSExtensionPrincipalClass` in Info.plist as
/// `$(PRODUCT_MODULE_NAME).MailExtension`.
final class MailExtension: NSObject, MEExtension {

    func handler(for session: MEComposeSession) -> MEComposeSessionHandler {
        ComposeSessionHandler()
    }
}
