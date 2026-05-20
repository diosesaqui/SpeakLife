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
        case testimony
        case bibleChatTopic
    }

    @Binding var isShowing: Bool
    @Binding var result: Result<MFMailComposeResult, Error>?
    
    let origin: Origin
    var prefillBody: String? = nil
    private let appVersion = "App version: \(APP.Version.stringNumber)"
    let isSubscribed: Bool
    
    var title: String {
        let isSubscribed = isSubscribed ? "✅" : ""
        switch origin {
        case .profile: return "Scholarship request"
        case .review: return "Prayer Request / Report an issue \(appVersion), \(isSubscribed)"
        case .newFeatures: return "Feature or content request"
        case .prayer: return "Prayer request"
        case .testimony: return "My Testimony 🙌"
        case .bibleChatTopic: return "Bible Chat: Topic Request 🙏"
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
        } else if let body = prefillBody {
            vc.setMessageBody(body, isHTML: false)
        }
        vc.setToRecipients(["speaklife@diosesaqui.com"])
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: UIViewControllerRepresentableContext<MailView>) {

    }
}
