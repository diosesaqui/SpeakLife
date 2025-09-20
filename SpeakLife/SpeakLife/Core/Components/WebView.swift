//
//  WebView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 11/26/23.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let urlString: String
    let allowedHosts: [String]

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // You can update your view when SwiftUI updates the view.
    }
}

struct PodcastView: View {
    var body: some View {
        NavigationView {
            WebView(urlString: "https://podcasts.apple.com/us/podcast/joel-osteen-podcast/id137254859", allowedHosts: ["https://podcasts.apple.com/us/podcast/joel-osteen-podcast"])
                .navigationBarTitle("Listen", displayMode: .inline)
        }
    }
}

class Coordinator: NSObject, WKNavigationDelegate {
    var parent: WebView

    init(_ parent: WebView) {
        self.parent = parent
    }
    
//    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//           if let host = navigationAction.request.url?.host {
//               if parent.allowedHosts.contains(where: { host.contains($0) }) {
//                   decisionHandler(.allow)
//                   return
//               }
//           }
//           decisionHandler(.cancel)
//       }
}

extension WebView {
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
