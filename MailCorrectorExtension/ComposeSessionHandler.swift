//
//  ComposeSessionHandler.swift
//  MailCorrectorExtension
//
//  Participates in a Mail compose session and vends the proofreading view
//  controller.
//
//  Note: MailKit does not expose the live draft body to a compose extension
//  (`MEComposeSession.mailMessage.rawData` is nil while the user is composing,
//  and there is no API to request it on demand). The proofreading view
//  therefore reads the text the user copies to the clipboard instead.
//

import Foundation
import MailKit

final class ComposeSessionHandler: NSObject, MEComposeSessionHandler {

    /// Provides the SwiftUI-backed review view controller for the compose window.
    func viewController(for session: MEComposeSession) -> MEExtensionViewController {
        ReviewViewController(session: session)
    }

    func mailComposeSessionDidBegin(_ session: MEComposeSession) {
        // No setup required when the session begins.
    }

    func mailComposeSessionDidEnd(_ session: MEComposeSession) {
        // No teardown required when the session ends.
    }
}
