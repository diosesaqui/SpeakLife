//
//  MailView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/27/22.
//

import MessageUI
import SwiftUI

struct MailView: UIViewControllerRepresentable {
    enum Origin {
        case profile
        case review
        case newFeatures
        case prayer
    }

    @Binding var isShowing: Bool
    @Binding var result: Result<MFMailComposeResult, Error>?
    
    let origin: Origin
    private let appVersion = "App version: \(APP.Version.stringNumber)"
    
    var title: String {
        switch origin {
        case .profile: return "Scholarship request"
        case .review: return "Prayer Request / Report an issue \(appVersion)"
        case .newFeatures: return "Request new feature"
        case .prayer: return "Prayer request"
        }
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {

        @Binding var isShowing: Bool
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(isShowing: Binding<Bool>,
             result: Binding<Result<MFMailComposeResult, Error>?>) {
            _isShowing = isShowing
            _result = result
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            defer {
                isShowing = false
            }
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            self.result = .success(result)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(isShowing: $isShowing,
                           result: $result)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(NSLocalizedString(title, comment: "mail title"))
        if origin == .profile {
            vc.setMessageBody("I would like to try a free year of SpeakLife!", isHTML: false)
        }
        vc.setToRecipients(["speaklife@diosesaqui.com"])
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: UIViewControllerRepresentableContext<MailView>) {

    }
}
