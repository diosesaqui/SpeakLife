//
//  DevotionalSubscriptionView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 2/2/25.
//

import SwiftUI
import FirebaseAnalytics

struct DevotionalSubscriptionView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @State var errorTitle = ""
    @State var isShowingError: Bool = false
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    let callBack: (() -> Void)
    var body: some View {
        VStack {
            // Curved header with image
            HeaderImageView(imageName: "sermonMount")
            
            Spacer()
            
            SubscriptionDetailsView(
                title: "30-Day Access to Devotionals with Jesus",
                description: """
                Access the premium devotionals to \
                start your day with love, wisdom and grace.
                """,
                disclaimer: "*30-day non-refundable subscription, begins at the time of purchase and will not auto-renew."
            )
            
            Spacer()
            
            ShimmerButton(colors: [Color.orange, Color.yellow.opacity(0.8)], buttonTitle: "Start Your 30-Day Journey with Jesus") {
                makePurchase()
            }
            .padding()
        
        }
        .background(
            ZStack {
//                Image("JesusHealing")
//                    .resizable()
//                    .aspectRatio(contentMode: .fill)
//                    .edgesIgnoringSafeArea(.all)
                 //   .brightness(0.05)
                Color.black
                    .edgesIgnoringSafeArea(.all)
            }
            )
        .alert(isPresented: $isShowingError, content: {
            Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("OK")))
        })
    }
    
    func buy() async {
        do {
            if let _ = try await subscriptionStore.purchaseWithID([devotionals]) {
                Analytics.logEvent(devotionals, parameters: nil)
                subscriptionStore.lastDevotionalPurchaseDate = Date()
            }
        } catch StoreError.failedVerification {
            errorTitle = "Your purchase could not be verified by the App Store."
            isShowingError = true
        } catch {
            print("Failed purchase for \(devotionals): \(error)")
            errorTitle = error.localizedDescription
            isShowingError = true
        }
    }
    
    private func makePurchase() {
        impactMed.impactOccurred()
        Task {
            withAnimation {
                declarationStore.isPurchasing = true
            }
            await buy()
            withAnimation {
                declarationStore.isPurchasing = false
                callBack()
            }
        }
    }
}

// MARK: - Header Image View with Curved Shape
struct HeaderImageView: View {
    let imageName: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: 250)
                    .clipShape(CurvedHeaderShape())
                    .overlay(
                        Text("Only $2.99")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(5)
                            .background(BlurView(style: .dark))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            .padding(.top, 20),
                        alignment: .top
                    )
            }
        }
        .frame(height: 250)
    }
}

// MARK: - Curved Shape for Header
struct CurvedHeaderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.8))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height * 0.8),
            control: CGPoint(x: rect.width / 2, y: rect.height * 1.2)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Subscription Details View
struct SubscriptionDetailsView: View {
    let title: String
    let description: String
    let disclaimer: String

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.title)
                .foregroundColor(.white)
                .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                .multilineTextAlignment(.center)
                

            Text(description)
                .font(.body)
                .foregroundColor(.white)

            Text(disclaimer)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding()
        .background(BlurView(style: .light))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

    }
}



struct DevotionalSubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        DevotionalSubscriptionView() { }
    }
}
