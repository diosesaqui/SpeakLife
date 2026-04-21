//
//  FeatureView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/12/24.
//

import SwiftUI
import StoreKit

struct Feature: Codable, Identifiable {
    var id = UUID()
    var subtitle: String
    var imageName: String = "checkmark.circle.fill"
    
    init(id: UUID = UUID(), subtitle: String, imageName: String) {
        self.id = id
        self.subtitle = subtitle
        self.imageName = imageName
    }
    
    init(subtitle: String) {
        self.id = UUID()
        self.subtitle = subtitle
    }

}



struct FeatureRow: View {
    @EnvironmentObject var appState: AppState
    var feature: Feature

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Spacer()
                .frame(width: 4)
            Image(systemName: feature.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .padding(.trailing, 8)
                .foregroundColor(Constants.gold)
            VStack(alignment: .leading) {
                Text(feature.subtitle)
                    .font(.caption)
                   // .font(.system(size: 14, weight: .medium, design: .rounded))
                
            }
            Spacer()

        }
    }
}

// Main subscription view
struct FeatureView: View {

    var valueProps: [Feature] {
        return allFeatures
    }
    
    
    let allPremiumFeatures = [
        Feature(subtitle: "Everything from Pro"),
        Feature(subtitle: "Audio declarations to claim victory"),
        Feature(subtitle: "Bible Bedtime Stories for peaceful rest"),
        ]
    
    let allFeatures = [
       // Feature(subtitle: "Unlock everything"),
//        Feature(subtitle: "🛡️ God's Protection over your mind and body"),
//        Feature(subtitle: "🙏 Devotionals filled with God's love & wisdom"),
//        Feature(subtitle: "❤️ Healing & health anchored in the Word"),
//        Feature(subtitle: "🌿 Feel God’s presence daily"),
//        Feature(subtitle: "💖 Grace that empowers"),
       
       
        Feature(subtitle: "Become skillful in applying God’s Word"),
        Feature(subtitle: "Make His Word your first response, not your last resort"),
        Feature(subtitle: "Devotionals that saturate you in God’s love and truth"),
        Feature(subtitle: "Walk in divine health, anchored in Scripture"),
        Feature(subtitle: "Renew your mind, and reshape your world"),

        
//        Feature(subtitle: "Unlock everything"),
//        Feature(subtitle: "Rewire your thoughts with God's living Word"),
//        Feature(subtitle: "Life-changing truth to renew your mind"),
//        Feature(subtitle: "Declare victory over your health, thoughts, and future"),
        
        ]
    
    let features: [Feature] = [

//        Feature(name: "Prosperity", subtitle: "Those who delight in the Lord and meditate day and night prosper in everything they do! Psalm 1:2-3", imageName: "infinity"),
//        Feature(name: "Inner Peace & Joy", subtitle: "Unlimited affirmations, Guided Prayers, and more to declare and activate a life of prosperity, peace, and health for yourself and your loved ones."/* Start declaring your blessings today!**Declare and fulfill a long, prosperous, peaceful life for you and your family."*/, imageName: "sparkles"),
//        Feature(name: "Guidance & Wisdom", subtitle: "365+ Daily Devotionals to grow with Jesus"/*Receive Jesus's love and be victorious from guilt, anxiety, and fear."*/, imageName: "book.fill"),
     
    ]

    var body: some View {
        VStack {
            ForEach(valueProps) { feature in
                FeatureRow(feature: feature)
                Spacer().frame(height: 8)
                
            }
        }
            .padding()
        }
}
