//
//  DeclarationContentView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/4/22.
//

import SwiftUI
import UIKit
import AVFoundation
import Photos

struct AppLogo: View {
    let height: CGFloat
    var fontSize: CGFloat = 26
    var body: some View {
        VStack {
            Image(uiImage: UIImage(named: "appIconDisplay") ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: height, height: height)
                .clipShape(Rectangle())
                .cornerRadius(12)
            Text("SpeakLife")
                .font(.system(size: fontSize, weight: .bold))
                .shadow(color: Color.white.opacity(0.6), radius: 4, x: 0, y: 2)
                .foregroundColor(.white)
        }
    }
}

// First-install banner encouraging users to speak declarations aloud like Jesus
struct SpeakAloudBanner: View {
    @AppStorage("hasShownSpeakAloudBanner") private var hasShownBanner = false
    @Binding var showBanner: Bool
    
    let onDismiss: () -> Void
    
    var body: some View {
        if !hasShownBanner && showBanner {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Constants.gold)
                
                Text("Speak these aloud like Jesus")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Button(action: dismissBanner) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            ))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
                    if showBanner {
                        dismissBanner()
                    }
                }
            }
        }
    }
    
    private func dismissBanner() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showBanner = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            hasShownBanner = true
            onDismiss()
        }
    }
}
struct DeclarationContentView: View {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    @ObservedObject var themeViewModel: ThemeViewModel
    @ObservedObject var viewModel: DeclarationViewModel
    @State private var isFavorite: Bool = false
    @State private var showShareSheet = false
    @State private var image: UIImage?
    @State private var showAnimation = false
    @State private var isCapturingScreenshot = false
    @State private var reviewCounter = 0
    @State private var completedAnimations: Set<String> = []
    @State private var animationResetTrigger = UUID() // Trigger animation reset
    
    private let degrees: Double = 90
    
    @StateObject private var coordinator = SpeechCoordinator()
    @State private var isMenuExpanded = false
    @State private var rotationAngle: Double = 0
    @State private var buttonVisibilities: [Bool] = [false, false]
    @State private var numberOfItems: Int = 2
    
    
    
    init(themeViewModel: ThemeViewModel,
         viewModel: DeclarationViewModel) {
        self.themeViewModel  = themeViewModel
        self.viewModel = viewModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
            TabView(selection: $viewModel.selectedTab) {
                ForEach(Array(viewModel.declarations.enumerated()), id: \.element.id) { index, declaration in
                    ZStack {
                            quoteLabel(declaration, geometry)
                                .onAppear {
                                }
                                .padding()
                                .rotationEffect(Angle(degrees: -degrees))
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                )
                                .contentShape(Rectangle()) // Fix touch targets
                                .offset(x: isMenuExpanded ? -geometry.size.width * 0.18 : 0)
                                .animation(.easeInOut, value: isMenuExpanded)


                        
                        intentVstack(declaration: declaration, geometry)
                            .rotationEffect(Angle(degrees: -degrees))
                        
                        if isFavorite {
                            VStack {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.8, blendDuration: 0.5)) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 150))
                                        .foregroundStyle(Color.red.opacity(0.7))
                                        .opacity(isFavorite ? 1 : 0)
                                        .scaleEffect(isFavorite ? 1.0 : 0.5)
                                        .rotationEffect(.degrees(360))
                                    
                                }
                                Spacer()
                                    .frame(height:geometry.size.height * 0.3)
                            }
                            
                            .rotationEffect(Angle(degrees: -degrees))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(.easeInOut(duration: 0.6)) {
                                        isFavorite = false // Fade out
                                    }
                                }
                            }
                        }
                    }
                    
                    .tag(index)
                    .sheet(isPresented: $showShareSheet) {
                        // On dismiss
                        image = nil
                    } content: {
                        if let image = image {
                            ShareSheet(activityItems: [image])
                        }
                    }
                }
            }
            // .scaleEffect(viewModel.showVerse ? 1.05 : 1)  // REMOVED - causing opacity issue
            .opacity(1.0)
            // .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.showVerse)  // REMOVED - causing opacity issue
            .onChange(of: viewModel.showVerse) { _ in
                // Clear animations immediately and trigger reset
                completedAnimations.removeAll()
                animationResetTrigger = UUID()
                
                // Immediately mark animation as complete for new state to prevent opacity issue
                if viewModel.selectedTab < viewModel.declarations.count {
                    let declaration = viewModel.declarations[viewModel.selectedTab]
                    let animationKey = "\(declaration.id)-\(viewModel.showVerse)-\(animationResetTrigger)"
                    completedAnimations.insert(animationKey)
                }
            }

            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.selectedTab) { newIndex in
                isMenuExpanded = false
                askForReview()
                let declaration = viewModel.declarations[newIndex]
                viewModel.setCurrent(declaration)
                
                // Track swipe event
                AnalyticsService.shared.track("swipe_affirmation", parameters: [
                    "declaration_id": declaration.id,
                    "declaration_index": newIndex,
                    // `.rawValue`, not the enum: the SDKs drop non-JSON values,
                    // which left this event with no category at all.
                    "category": declaration.category.rawValue,
                    "content_type": declaration.contentType.rawValue,
                    // Defaulted, not passed as `Bool?`: an unset optional would
                    // drop the key and skew the ratio toward whatever remained.
                    "is_favorite": declaration.isFavorite ?? false
                ])
                // Activation. Speaking a declaration is the app's core act, so
                // the first one is the moment an install becomes a user — the
                // number every acquisition and onboarding decision hangs off.
                // Both calls are one-shot and dedupe internally.
                GrowthMetrics.shared.trackActivation(action: "declaration_spoken")
                GrowthMetrics.shared.trackFeatureFirstUse("declarations")
                // Fix 3: Increment affirmations spoken counter for badge tracking
                UserDefaults.standard.set(
                    UserDefaults.standard.integer(forKey: "totalAffirmationsSpoken") + 1,
                    forKey: "totalAffirmationsSpoken"
                )
                // Track declaration count for trial experience
                TrialExperienceService.shared.onDeclarationSpoken()
                // Reset animations for new declaration
                completedAnimations.removeAll()
                animationResetTrigger = UUID()
                
                // Immediately mark animation as complete for new declaration to prevent opacity issue
                let animationKey = "\(declaration.id)-\(viewModel.showVerse)-\(animationResetTrigger)"
                completedAnimations.insert(animationKey)
            }
                
            .frame(width: geometry.size.height, height: geometry.size.width)
            .rotationEffect(.degrees(90), anchor: .topLeading)
            .offset(x: geometry.size.width)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                self.showShareSheet = false
            }
            
            // First-install banner centered and contained
           
            }
        }
        .onAppear {
            // Safety check on app launch
            if appState.showScreenshotLabel {
                appState.showScreenshotLabel = false
            }
            
            if viewModel.selectedTab >= viewModel.declarations.count && !viewModel.declarations.isEmpty {
                viewModel.selectedTab = 0
            }
        }
       
       // }
    }
    
    func getButtonVisibility(declaration: Declaration) {
        numberOfItems = 3
        if declaration.bibleVerseText != nil {
            numberOfItems += 1
        }
        buttonVisibilities = Array(repeating: false, count: numberOfItems)
    }
    
    
    
    func prepareShareItems() -> [UIImage] {
        guard let image = image else { return [] }
        return [image]//, message]
    }

    
    func requestReview() {
        viewModel.requestReview = true
        appState.helpUsGrowCount += 1
    }
    
    private func askForReview() {
        reviewCounter += 1
        if reviewCounter % 7 == 0 {
            viewModel.requestReview = true
        }
    }
    
    
    private func intentVstack(declaration: Declaration, _ geometry: GeometryProxy) -> some View {
        VStack {
            
            Spacer()
            intentStackButtons(declaration: declaration)
                .opacity(appState.showScreenshotLabel ? 0 : 1)
            VStack {
                screenshotLabel()
                Spacer()
                    .frame(height: geometry.size.height * 0.05)
            }
            
            Spacer()
                .frame(height: horizontalSizeClass == .compact ? geometry.size.height * 0.10 : geometry.size.height * 0.25)
            
        }
    }
    
    func showButtonsInSequence() {
            for index in buttonVisibilities.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) { // Adjust the delay as needed
                    withAnimation {
                        buttonVisibilities[index] = true
                    }
                }
            }
        }
    
    func hideButtonsInSequence(completion: @escaping () -> Void) {
            let totalButtons = buttonVisibilities.count
            for index in buttonVisibilities.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    withAnimation {
                        buttonVisibilities[totalButtons - 1 - index] = false
                    }
                    if index == totalButtons - 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            completion()
                        }
                    }
                }
            }
        }
    
        
    func getButton(for index: Int, declaration: Declaration) -> some View {
        var buttons:[AnyView] = [
            AnyView(DeclarationMenuButton(iconName: "square.and.arrow.up", label: "SHARE") {
                withAnimation(.easeInOut) {
                    isMenuExpanded = false
                }
                shareTapped(declaration: declaration) }),
            AnyView(DeclarationMenuButton(iconName:  (declaration.isFavorite ?? false) ? "heart.fill" : "heart", label: "FAVORITE") {
                favoriteTapped(declaration: declaration)

            }),
        ]
        
        if declaration.bibleVerseText != nil {
            buttons.append(AnyView(DeclarationMenuButton(iconName: viewModel.showVerse ? "arrowshape.zigzag.right.fill" : "arrowshape.zigzag.forward", label: "VERSE") { showVerse(declaration: declaration) }))
        }
        if index < buttons.count {
            return AnyView(buttons[index]
                .zIndex(Double(index))
                .offset(x: buttonVisibilities[index] ? 0 : -20) // Shift down slightly on exit
                .opacity(buttonVisibilities[index] ? 1 : 0) // Fade out
                .animation(.easeInOut, value: buttonVisibilities[index])
                           )
        } else {
            return AnyView(EmptyView())
        }
    }
    
    
    @ViewBuilder
    private func screenshotLabel() -> some View {
        if appState.showScreenshotLabel {
            AppLogo(height: 90)
       }
    }
    
    private func quoteLabel(_ declaration: Declaration, _ geometry: GeometryProxy) -> some View  {
        let currentQuote = viewModel.showVerse ? declaration.bibleVerseText ?? declaration.text : declaration.text
        
        return VStack(spacing: 8) {
            
            Spacer()
                    .frame(height: geometry.size.height * 0.04)
            
            QuoteLabel(themeViewModel: themeViewModel, quote: currentQuote) {
                let animationKey = "\(declaration.id)-\(viewModel.showVerse)-\(animationResetTrigger)"
                // Only add to completed if not already there
                if !completedAnimations.contains(animationKey) {
                    // Small delay to ensure animation completes before showing subtitle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        completedAnimations.insert(animationKey)
                    }
                }
            }
                .foregroundColor(themeViewModel.selectedTheme.fontColor)
                .frame(width: geometry.size.width * 0.98)
                .shadow(color: .black, radius: themeViewModel.selectedTheme.blurEffect ? 10 : 0)
                .id(animationResetTrigger) // Force QuoteLabel recreation when trigger changes
            
            // Scripture reference — fades in after declaration animation completes
            let animKey = "\(declaration.id)-\(viewModel.showVerse)-\(animationResetTrigger)"
            let referenceVisible = completedAnimations.contains(animKey)
            let subtitle = viewModel.subtitle(declaration)
            
            if !subtitle.isEmpty {
                VStack(spacing: 6) {
                    // Thin separator line — matches card aesthetic
                    Rectangle()
                        .fill(themeViewModel.selectedTheme.fontColor.opacity(0.35))
                        .frame(width: 44, height: 1)
                    
                    // Scripture reference text — same font family as declaration, smaller, italic
                    Text(subtitle)
                        .font(themeViewModel.selectedFontForBook.map { font in
                            // Italicize using Font modifier if possible
                            font
                        } ?? .system(size: 18, weight: .light, design: .serif))
                        .italic()
                        .foregroundColor(themeViewModel.selectedTheme.fontColor.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .tracking(1.2) // Elegant letter-spacing for scripture refs
                }
                .shadow(color: .black.opacity(themeViewModel.selectedTheme.blurEffect ? 0.6 : 0.2), radius: themeViewModel.selectedTheme.blurEffect ? 8 : 2)
                .opacity(referenceVisible ? 1.0 : 0.0)
                .scaleEffect(referenceVisible ? 1.0 : 0.9)
                .offset(y: referenceVisible ? 0 : 8)
                .animation(.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0.1).delay(0.35), value: referenceVisible)
                .padding(.top, 10)
            }
            
            Spacer()
                .frame(height: geometry.size.height * 0.34)
        }
//        .onAppear {
//            Event.trackContent(
//                type: "declaration",
//                id: declaration.id,
//                action: "viewed",
//                metadata: [
//                    "declaration_text": declaration.text.prefix(50),
//                    "category": declaration.category.rawValue,
//                    "has_verse": declaration.bibleVerseText != nil,
//                    "is_custom": declaration.category == .myOwn,
//                    "view_mode": viewModel.showVerse ? "verse" : "affirmation"
//                ]
//            )
//        }
    }
    
    func setImage(completion: @escaping () -> Void) {
        // Create a snapshot view specifically for screenshots
        createScreenshotImage { capturedImage in
            self.image = capturedImage
            completion()
        }
    }
    
    private func createScreenshotImage(completion: @escaping (UIImage?) -> Void) {
        guard !viewModel.declarations.isEmpty,
              viewModel.selectedTab < viewModel.declarations.count else { 
            completion(nil)
            return
        }
        
        let declaration = viewModel.declarations[viewModel.selectedTab]
        
        // Create a SwiftUI view for the screenshot
        let screenshotView = ZStack {
            // Background
            if themeViewModel.showUserSelectedImage, let selectedImage = themeViewModel.selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(themeViewModel.selectedTheme.backgroundImageString)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            
            // Black overlay if needed
            Rectangle()
                .fill(Color.black.opacity(themeViewModel.selectedTheme.blurEffect ? 0.25 : 0))
            
            // Declaration content - adaptive layout
            VStack(spacing: 0) {
                // Top spacer - flexible
                Spacer(minLength: 50)
                
                // Content container
                VStack(spacing: 16) {
                    // Main declaration text
                    Text(viewModel.showVerse ? declaration.bibleVerseText ?? declaration.text : declaration.text)
                        .font(themeViewModel.selectedFont ?? .largeTitle)
                        .foregroundColor(themeViewModel.selectedTheme.fontColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.3) // Allow more shrinking for long text
                        .padding(.horizontal, 40)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.6) // Limit max height
                        .shadow(color: .black, radius: themeViewModel.selectedTheme.blurEffect ? 10 : 0)
                    
                    // Subtitle
                    Text(viewModel.subtitle(declaration))
                        .foregroundColor(.white.opacity(0.9))
                        .font(themeViewModel.selectedFontForBook ?? .caption)
                        .shadow(color: .black, radius: themeViewModel.selectedTheme.blurEffect ? 10 : 0)
                        .padding(.horizontal, 30)
                }
                
                // Middle spacer - will shrink if text is long
                Spacer(minLength: 30)
                
                // App logo - stays visible
                AppLogo(height: 70)
                    .padding(.bottom, 20)
                
                // Bottom spacer - flexible
                Spacer(minLength: 40)
            }
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        
        // Render the SwiftUI view to an image
        let controller = UIHostingController(rootView: screenshotView)
        controller.view.bounds = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        controller.view.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: controller.view.bounds.size)
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        
        completion(image)
    }
    
    private func shareTapped(declaration: Declaration) {
        viewModel.setCurrent(declaration)
        Juice.play(.tapSolid)

        // Fix 3: Increment social shares counter for badge tracking
        UserDefaults.standard.set(
            UserDefaults.standard.integer(forKey: "totalSocialShares") + 1,
            forKey: "totalSocialShares"
        )

        // Create screenshot without affecting visible UI
        setImage { 
            // Show share sheet immediately after image is ready
            self.showShareSheet = true
        }

        AnalyticsService.shared.trackShare(
            contentType: "declaration",
            contentId: declaration.id,
            shareMethod: "screenshot",
            metadata: [
                "declaration_text": declaration.text.prefix(100),
                "category": declaration.category.rawValue,
                "has_verse": declaration.bibleVerseText != nil,
                "is_custom": declaration.category == .myOwn,
                "theme": themeViewModel.selectedTheme.backgroundImageString
            ]
        )
        
        appState.shareDiscountTry += 1
        StreakIntegrationManager.notifyAffirmationShared()
    }
    
    private func speakTapped(declaration: Declaration) {
        Juice.play(.tapLight)
        
        Event.trackUserAction(
            "speech_button_tapped",
            category: "declaration",
            metadata: [
                "declaration_id": declaration.id,
                "declaration_text": declaration.text.prefix(50),
                "category": declaration.category.rawValue,
                "is_custom": declaration.category == .myOwn
            ]
        )
        
        affirm(declaration, isAffirmation: viewModel.showVerse)
        
    }
    
    private func showVerse(declaration: Declaration) {
        Juice.play(.tapLight)
        withAnimation(DS.Motion.smooth) {
            toggleDeclaration(declaration)
        }
    }
    
    private func favoriteTapped(declaration: Declaration) {
        let wasFavorite = declaration.isFavorite ?? false
        
        Event.trackUserAction(
            wasFavorite ? "unfavorite_tapped" : "favorite_tapped",
            category: "declaration",
            metadata: [
                "declaration_id": declaration.id,
                "declaration_text": declaration.text.prefix(50),
                "category": declaration.category.rawValue,
                "is_custom": declaration.category == .myOwn,
                "total_favorites": viewModel.favorites.count,
                "action": wasFavorite ? "remove" : "add"
            ]
        )
        
        favorite(declaration)
        withAnimation(Juice.Feel.favorite.motion) {
            self.isFavorite = !wasFavorite
        }
        // Fix 3: Increment favorites counter when adding (not removing) a favorite
        if !wasFavorite {
            UserDefaults.standard.set(
                UserDefaults.standard.integer(forKey: "totalFavoritesAdded") + 1,
                forKey: "totalFavoritesAdded"
            )
        }
        // Matched feedback: a warm heartbeat when adding, a soft tap when removing.
        Juice.play(wasFavorite ? .unfavorite : .favorite)
        appState.offerDiscountTry += 1
        if !subscriptionStore.isPremium, appState.offerDiscountTry % 5 == 0 {
            viewModel.showDiscountView.toggle()
        }
    }
    
    @ViewBuilder
    private func intentStackButtons(declaration: Declaration) -> some View  {
        HStack(spacing: DS.Spacing.lg) {
                
                Menu {
                    Button("Instagram Stories") {
                        // Create screenshot without affecting UI
                        setImage() {
                            if let image = prepareShareItems().first {
                                shareToInstagramStories(image: image)
                            }
                        }
                    }
                    Button("Other Apps") {
                        shareTapped(declaration: declaration)
                    }
                } label: {
                    CapsuleImageButton(title: "tray.and.arrow.up") { }
                }
                
                
                CapsuleImageButton(title: (declaration.isFavorite ?? false) ? "heart.fill" : "heart") {
                    favoriteTapped(declaration: declaration)
                }

                // TODO: Read aloud button — pending Google Cloud Neural2 TTS integration
                // CapsuleImageButton(title: coordinator.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2") {
                //     if coordinator.isSpeaking {
                //         coordinator.synthesizer.stopSpeaking(at: .immediate)
                //         coordinator.isSpeaking = false
                //         AudioPlayerService.shared.playMusic()
                //     } else {
                //         speakTapped(declaration: declaration)
                //     }
                // }

                if declaration.bibleVerseText != nil {
                    CapsuleImageButton(title: viewModel.showVerse ? "arrowshape.zigzag.right.fill" : "arrowshape.zigzag.forward") {
                        showVerse(declaration: declaration)
                    }
                }
                
                // Animation settings toggle
               // AnimationToggleButton()
                
        }
        .foregroundColor(.white)
    }
    
    private func affirm(_ declaration: Declaration, isAffirmation: Bool) {
        AudioPlayerService.shared.pauseMusic()
        let text = isAffirmation ? declaration.text : declaration.bibleVerseText
        // Use female voice for affirmations, male for Bible verses
        let gender: AVSpeechSynthesisVoiceGender = isAffirmation ? .female : .male
        if isAffirmation {
            coordinator.speakText("Repeat after me", gender: gender)
        }
        coordinator.speakText(text!, gender: gender)
    }
    
    private func setCurrentDelcaration(declaration: Declaration) {
        viewModel.setCurrent(declaration)
    }
    
    private func toggleDeclaration(_ declaration: Declaration) {
        viewModel.toggleDeclaration(declaration)
    }
    
    
    private func favorite(_ declaration: Declaration) {
        viewModel.favorite(declaration: declaration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            viewModel.requestReview.toggle()
        }
    }
}

extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}


struct ShareSheet: UIViewControllerRepresentable {
    typealias Callback = (_ activityType: UIActivity.ActivityType?, _ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void
    
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil
    let callback: Callback? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = callback
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        
    }
}


class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc private func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Save failed: \(error.localizedDescription)")
        }
    }
}

func shareToInstagramStories(image: UIImage) {
    let _ = PHPhotoLibrary.shared()
    
    PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
            switch status {
            case .authorized, .limited:
                saveImageToPhotos(image: image)
            case .denied, .restricted:
                showPhotosPermissionAlert()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

private func saveImageToPhotos(image: UIImage) {
    PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
    }) { success, error in
        DispatchQueue.main.async {
            if success {
                showImageSavedAlert()
            } else if let error = error {
                print("Failed to save image: \(error.localizedDescription)")
            }
        }
    }
}

private func showImageSavedAlert() {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let rootViewController = window.rootViewController else {
        return
    }
    
    let alert = UIAlertController(
        title: "🎉 Image Saved!",
        message: "Your affirmation has been saved to Photos. Open Instagram and create a new Story to share it!",
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "Open Instagram", style: .default) { _ in
        if let instagramURL = URL(string: "instagram://story-camera"),
           UIApplication.shared.canOpenURL(instagramURL) {
            UIApplication.shared.open(instagramURL)
        }
    })
    
    alert.addAction(UIAlertAction(title: "OK", style: .cancel))
    
    var topController = rootViewController
    while let presentedController = topController.presentedViewController {
        topController = presentedController
    }
    
    topController.present(alert, animated: true)
}

private func showPhotosPermissionAlert() {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let rootViewController = window.rootViewController else {
        return
    }
    
    let alert = UIAlertController(
        title: "Photos Access Needed",
        message: "To save your affirmation, please allow access to Photos in Settings.",
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    })
    
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    
    var topController = rootViewController
    while let presentedController = topController.presentedViewController {
        topController = presentedController
    }
    
    topController.present(alert, animated: true)
}


