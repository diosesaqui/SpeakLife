//
//  AbbasLoveView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 6/19/23.
//

import SwiftUI
import FirebaseAnalytics

struct AbbasLoveView: View {
    
    let pageContentViews = [
        PageContent(verse: "You may not know me, but I know everything about you.", book: "Psalm 139:1"),
        PageContent(verse: "I know when you sit down and when you rise up.", book: "Psalm 139:2"),
        PageContent(verse: "I am familiar with all your ways.", book: "Psalm 139:3"),
        PageContent(verse: "Even the very hairs on your head are numbered.", book: "Matthew 10:29-31"),
        PageContent(verse: "For you were made in my image.", book: "Genesis 1:27"),
        PageContent(verse: "In me you live and move and have your being.", book: "Acts 17:28"),
        PageContent(verse: "For you are my offspring.", book: "Acts 17:28"),
        PageContent(verse: "I knew you even before you were conceived.", book: "Jeremiah 1:4-5"),
        PageContent(verse: "I chose you when I planned creation.", book: "Ephesian 1:11-12"),
        PageContent(verse: "You were not a mistake, for all your days are written in my book.", book: "Psalm 139:15-16"),
        PageContent(verse: "I determined the exact time of your birth and where you would live.", book: "Acts 17:26"),
        PageContent(verse: "You are fearfully and wonderfully made.", book: "Psalm 139:14"),
        PageContent(verse: "I knit you together in your mother's womb.", book: "Psalm 139:13"),
        PageContent(verse: "And brought you forth on the day you were born.", book: "Psalm 71:6"),
        PageContent(verse: "I have been misrepresented by those who don't know me.", book: "John 8:41-44"),
        PageContent(verse: "l am not distant and angry, but am the complete expression of love.", book: "1 John 4:16"),
        PageContent(verse: "And it is my desire to lavish my love on you.", book: "1 John 3:1"),
        PageContent(verse: "Simply because you are my child and I am your Father.", book: "1 John 3:1"),
        PageContent(verse: "I offer you more than your earthly father ever could.", book: "Matthew 7:11"),
        PageContent(verse: "For I am the perfect Father.", book: "Matthew 5:48"),
        PageContent(verse: "Every good gift that you receive comes from my hand.", book: "James 1:17"),
        PageContent(verse: "For I am your provider and I meet all your needs.", book: "Matthew 6:31-33"),
        PageContent(verse: "My plan for your future has always been filled with hope.", book: "Jeremiah 29:11"),
        PageContent(verse: "Because I love you with an everlasting love.", book: "Jeremiah 31:3"),
        PageContent(verse: "My thoughts toward you are countless as the sand on the seashore.", book: "Psalm 139:17-18"),
        PageContent(verse: "And I rejoice over you with singing.", book: "Zephaniah 3:17"),
        PageContent(verse: "I will never stop doing good to you.", book: "Jeremiah 32:40"),
        PageContent(verse: "For you are my treasured possession.", book: "Exodus 19:5"),
        PageContent(verse: "I desire to establish you with all My heart and all My soul.", book: "Jeremiah 32:41"),
        PageContent(verse: "And I want to show you great and marvelous things.", book: "Jeremiah 33:3"),
        PageContent(verse: "If you seek Me with all your heart, you will find Me.", book: "Deuteronomy 4:29"),
        PageContent(verse: "Delight in Me and I will give you the desires of your heart.", book: "Psalm 37:4"),
        PageContent(verse: "For it is I who gave you those desires.", book: "Philippians 2:13"),
        PageContent(verse: "I am able to do more for you than you could possibly imagine.", book: "Ephesians 3:20"),
        PageContent(verse: "For l am your greatest encourager.", book: "2 Thessalonians 2:16-17"),
        PageContent(verse: "I am also the Father who comforts you in all your troubles.", book: "2 Corinthians 1:3-4"),
        PageContent(verse: "When you are brokenhearted, I am close to you.", book: "Psalm 34:18"),
        PageContent(verse: "As a shepherd carries a lamb, I have carried you close to my heart.", book: "Isaiah 40:11"),
        PageContent(verse: "One day I will wipe away every tear from your eyes.", book: "Revelation 21:3-4"),
        PageContent(verse: "And l'Il take away all the pain you have suffered on this earth.", book: "Revelation 21:3-4"),
        PageContent(verse: "I am your Father, and I love you even as I love my Son, Jesus.", book: "John 17:23"),
        PageContent(verse: "For in Jesus, my love for you is revealed.", book: "John 17:26"),
        PageContent(verse: "He is the exact representation of My being.", book: "Hebrews 1:3"),
        PageContent(verse: "He came to demonstrate that I am for you, not against you.", book: "Romans 8:31"),
        PageContent(verse: "And to tell you that I am not counting your sins.", book: "2 Corinthians 5:18-19"),
        PageContent(verse: "Jesus died so that you and I could be reconciled.", book: "2 Corinthians 5:18-19"),
        PageContent(verse: "His death was the ultimate expression of My love for you.", book: "1 John 4:10"),
        PageContent(verse: "I gave up everything I loved that I might gain your love.", book: "Romans 8:31-32"),
        PageContent(verse: "If you receive the gift of My Son Jesus, you receive me.", book: "1 John 2:23"),
        PageContent(verse: "And nothing will ever separate you from My love again.", book: "Romans 8:38-39"),
        PageContent(verse: "Come home and I’ll throw the biggest party heaven has ever seen.", book: "Luke 15:7"),
        PageContent(verse: "I have always been Father, and will always be Father.", book: "Ephesians 3:14-15"),
        PageContent(verse: "My question is...Will you be my child?", book: "John 1:12-13"),
        PageContent(verse: "l am waiting for you.", book: "Luke 15:11-32"),
        PageContent(verse: "Love, Your Dad", book: "")
    ]
    
    @EnvironmentObject var appState: AppState
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer from top
                    Spacer().frame(height: proxy.size.height * 0.05)

                    // ✉️ Title
                    Text("Heavenly Father’s Love Letter 💌")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .shadow(radius: 4)

                    // Extra breathing room before pages
                    Spacer().frame(height: proxy.size.height * 0.06)

                    // 📄 PageView
                    PageView(views: pageContentViews)
                        .frame(height: proxy.size.height * 0.60)
                        .padding(.horizontal)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.6), value: pageContentViews.count)

                    // 🔁 Reset Button
                    Button(action: {
                        withAnimation(.easeInOut) {
                            appState.loveLetterIndex = 0
                        }
                    }) {
                        Text("Start from beginning")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
            }
            .background {
                ZStack {
                    Image("lakeTrees")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.all)

                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.35),
                            Color.black.opacity(0.7)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .edgesIgnoringSafeArea(.all)
                }
            }
            .onAppear {
                Analytics.logEvent(Event.devotionalTapped, parameters: nil)
                appState.abbasLoveAdded = false
            }
        }
    }
}

struct PageContent: View {
    let verse: String
    let book: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(verse)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 24)

            Text(book)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

struct PageView<Content: View>: View {
    @EnvironmentObject var appState: AppState
    var views: [Content]

    var body: some View {
        TabView(selection: $appState.loveLetterIndex) {
            ForEach(views.indices, id: \.self) { index in
                views[index]
                    .tag(index)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.4), value: appState.loveLetterIndex)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
        .animation(.easeInOut(duration: 0.4), value: appState.loveLetterIndex)
    }
}
