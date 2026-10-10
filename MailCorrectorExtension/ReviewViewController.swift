//
//  ReviewViewController.swift
//  MailCorrectorExtension
//
//  An MEExtensionViewController that hosts the SwiftUI proofreading UI inside
//  the Mail compose window popover.
//

import AppKit
import SwiftUI
import MailKit

final class ReviewViewController: MEExtensionViewController {

    init(session _: MEComposeSession) {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        // MailKit does not expose the live draft body to a compose extension,
        // so the proofreader reads the text the user copied to the clipboard.
        let clipboardText = NSPasteboard.general.string(forType: .string) ?? ""
        let model = ReviewViewModel(inputText: clipboardText)
        let hosting = NSHostingController(rootView: ReviewView(model: model))
        // A compact popover size suitable for the compose window.
        hosting.view.frame = NSRect(x: 0, y: 0, width: 380, height: 620)
        view = hosting.view
    }
}
