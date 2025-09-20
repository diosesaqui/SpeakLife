//
//  TipsView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/30/23.
//

import SwiftUI

let tips = [
    
    "The number one goal for this app is to teach you about the promises of God, help you speak them over your life and grow a more initimate relationship with our best friend Jesus!",
    "Peace and Calm: Affirmations often bring peace as the words from the Bible are reassuring and comforting.",
    "Divine Guidance: Reciting affirmations/scripture can serve as reminders of divine guidance and God’s wisdom in making decisions.",
    "Renewed Mindset: Regularly meditating on Bible affirmations will upgrade your way of thinking and expectation!",
    "Whatever trial you face, God's word will turn it in your favor! Find 3 to 5 Bible verses from a category you need. Meditate on them until they fill your heart, and speak them several times a day.",
    "Create your own affirmations and have them sent to you through out the day!",
    "Add the scriptures to your favorites so they will be readily accessible for any time of day. Even schedule to have them sent to you daily!",
    "Warrior Resilience: By focusing on the promises and truths found in scripture, you'll cultivate emotional resilience and the ability to conquer life's trials. The practice of Bible affirmations can serve as a powerful reminder of God's unwavering support in times of difficulty.",
    "Deeper Spiritual Connection: As you internalize the affirmations rooted in God's Word, you'll start recognizing your true worth and potential.",
]

struct TipsView: View {
    @EnvironmentObject var appState: AppState
    let tips: [String]
    @State var selection = 0
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.cyan, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
    
           
            VStack {
                Spacer()
                    .frame(height: 100)
                Text("How to use and benefit from Speaklife to fulfill your victory!🛡🗡")
                    .font(.title)
                    .foregroundColor(.black)
                    .padding()
                
                Spacer()
                    .frame(height: 50)
                
                TabView {
                    ForEach(tips, id: \.self) { item in
                        Text(item)
                            .font(.title2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
            
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                
                Spacer()
            }
        }
        .onAppear() {
            appState.newSettingsAdded = false
        }
    }
}

struct TipsView_Previews: PreviewProvider {
    static var previews: some View {
        TipsView(tips: tips)
    }
}
