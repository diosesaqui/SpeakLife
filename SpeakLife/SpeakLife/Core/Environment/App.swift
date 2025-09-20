//
//  App.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/30/22.
//

import Foundation

struct APP {
    enum Version  {
        static var stringNumber: String {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        }
        
        static var sharedSecret: String {
            "437413ffc42448a28a4f6daa851c1820"
        }
    }
    
    enum Product {
        static var urlID: String {
            "https://apps.apple.com/app/id1617492998"
        }
        
        static var instagramURL: String {
            "https://www.instagram.com/speaklife.affirmationsapp"
        }
        
        static var googleAdUnitBannerID: String {
            "ca-app-pub-4361689433807539/7209066019"
        }
        
        static var googleAdUnitBannerID2: String {
            "ca-app-pub-4361689433807539/7933731965"
        }
        
        static var googleOpenAppAdUnitID: String {
            "ca-app-pub-4361689433807539/2438340662"
        }
        
        static var googleInterstitialAdUnitID: String {
            "ca-app-pub-4361689433807539/4343229527"
        }
        
        static var rapidAPIKey: String {
            "59d7338d06msh8bf6800ac4c9dbbp163ed2jsn4802c2f79391"
        }

    }
}
