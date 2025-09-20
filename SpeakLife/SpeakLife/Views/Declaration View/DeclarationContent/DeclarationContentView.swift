//
//  DeclarationContentView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/4/22.
//

import SwiftUI
import FirebaseAnalytics
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
                .clipShape(Circle())
            Text("SpeakLife")
                .font(.system(size: fontSize, weight: .bold))
                .shadow(color: Color.white.opacity(0.6), radius: 4, x: 0, y: 2)
                .foregroundColor(.white)
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
    @State private var reviewCounter = 0
    
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
                                .padding()
                                .rotationEffect(Angle(degrees: -degrees))
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                )
                                .offset(x: isMenuExpanded ? -geometry.size.width * 0.18 : 0)
                                .animation(.easeInOut, value: isMenuExpanded)


                        
                        if !showShareSheet {
                            intentVstack(declaration: declaration, geometry)
                                .rotationEffect(Angle(degrees: -degrees))
                
                        }
                        
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
                    .onChange(of: image) { newImage in
                        if newImage != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showShareSheet = true
                            }
                        }
                    }
                    .sheet(isPresented: Binding<Bool>(
                        get: {
                            showShareSheet && image != nil
                        },
                        set: { newValue in
                            showShareSheet = newValue
                            if !newValue {
                                image = nil // clear image after dismiss
                            }
                        }
                    )) {
                        if let image = image {
                            ShareSheet(activityItems: [image])
                        }
                    }
                }
            }
            .scaleEffect(viewModel.showVerse ? 1.05 : 1)
            .opacity(viewModel.showVerse ? 1 : 0.9)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.showVerse)

            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.selectedTab) { newIndex in
                isMenuExpanded = false
                askForReview()
                let declaration = viewModel.declarations[newIndex]
                viewModel.setCurrent(declaration)
//                if declaration.book != nil {
//                    viewModel.showVerse = true
//                }
                
//                if viewModel.selectedCategory == .myOwn || viewModel.selectedCategory == .favorites {
//                    viewModel.showVerse = false
//                } else {
//                    viewModel.showVerse = true
//                }
                
            }
                
            .frame(width: geometry.size.height, height: geometry.size.width)
            .rotationEffect(.degrees(90), anchor: .topLeading)
            .offset(x: geometry.size.width)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                self.showShareSheet = false
            }
            }
        }
    }
    
    func getButtonVisibility(declaration: Declaration) {
        print("Updated buttonVisibilities previous count: \(buttonVisibilities.count) RWRW")
        numberOfItems = 3 // Default
            if declaration.bibleVerseText != nil {
                numberOfItems += 1 // Add the "VERSE" button
            }
        buttonVisibilities = Array(repeating: false, count: numberOfItems)
        print("Updated buttonVisibilities count: \(buttonVisibilities.count) RWRW")
    }
    
    func prepareShareItems() -> [UIImage] {
        guard let image = image else { return [] }
       // ImageSaver().writeToPhotoAlbum(image: image)
     //   let message = "Check out SpeakLife - Bible Meditation and email speaklife@diosesaqui.com for a 30-day free pass. \n\(APP.Product.urlID)"
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
                        print("Animating button at index: \(index) RWRW")
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
                    // Call the completion handler after the last animation
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
            // AnyView(DeclarationMenuButton(iconName: "speaker.wave.2.fill", label: "SPEAK") { speakTapped(declaration: declaration)})
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
        
        VStack(spacing: 1) {
            
            Spacer()
                    .frame(height: geometry.size.height * 0.05)
            
            QuoteLabel(themeViewModel: themeViewModel, quote: viewModel.showVerse ? declaration.bibleVerseText ?? declaration.text : declaration.text)
                .foregroundColor(themeViewModel.selectedTheme.fontColor)
                .frame(width: geometry.size.width * 0.98)
                .shadow(color: .black, radius: themeViewModel.selectedTheme.blurEffect ? 10 : 0)
            
            Text(viewModel.subtitle(declaration))
                .foregroundColor(.white.opacity(0.9))
                .font(themeViewModel.selectedFontForBook ?? .caption)
                .shadow(color: .black, radius: themeViewModel.selectedTheme.blurEffect ? 10 : 0)
            
            Spacer()
                .frame(height: geometry.size.height * 0.44)
        }.onAppear {
            Analytics.logEvent(Event.swipe_affirmation, parameters: nil)
        }
    }
    
    func setImage(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let capturedImage = window.rootViewController?.view.toImage() else {
                return
            }
            self.image = capturedImage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completion()
            }
        }
    }
    
    private func shareTapped(declaration: Declaration) {
        viewModel.setCurrent(declaration)
        
        withAnimation {
            appState.showScreenshotLabel = true
        }
        DispatchQueue.main.async {
            RunLoop.main.perform {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1){
                setImage { }
            }
        }
        }

        Analytics.logEvent(Event.shareTapped, parameters: ["share": declaration.text.prefix(50)])
        Selection.shared.selectionFeedback()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                appState.showScreenshotLabel = false
                appState.shareDiscountTry += 1
            }
        }
        StreakIntegrationManager.notifyAffirmationShared()
    }
    
    private func speakTapped(declaration: Declaration) {
        Selection.shared.selectionFeedback()
        affirm(declaration, isAffirmation: viewModel.showVerse)
        Analytics.logEvent(Event.speechTapped, parameters: ["declaration": declaration.text])
        
    }
    
    private func showVerse(declaration: Declaration) {
        Selection.shared.selectionFeedback()
        withAnimation {
            toggleDeclaration(declaration)
        }
    }
    
    private func favoriteTapped(declaration: Declaration) {
        let wasFavorite = declaration.isFavorite ?? false
        favorite(declaration)
        self.isFavorite = !wasFavorite // Use the inverse of the original state for animation
        Analytics.logEvent(Event.favoriteTapped, parameters: ["declaration": declaration.text.prefix(100)])
        Selection.shared.selectionFeedback()
        appState.offerDiscountTry += 1
        if !subscriptionStore.isPremium, appState.offerDiscountTry % 5 == 0 {
            viewModel.showDiscountView.toggle()
        }
    }
    
    @ViewBuilder
    private func intentStackButtons(declaration: Declaration) -> some View  {
        if !appState.showScreenshotLabel {
            HStack(spacing: 24) {
                
                Menu {
                    Button("Instagram Stories") {
                        withAnimation {
                            appState.showScreenshotLabel = true
                        }
                        DispatchQueue.main.async {
                            RunLoop.main.perform {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    setImage() {
                                        if let image = prepareShareItems().first {
                                            shareToInstagramStories(image: image)
                                            withAnimation {
                                                appState.showScreenshotLabel = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Button("Other Apps") {
                        shareTapped(declaration: declaration)
                    }
                } label: {
                    CapsuleImageButton(title: "tray.and.arrow.up") { }
                }
                
//                CapsuleImageButton(title: "tray.and.arrow.up") {
//                    shareTapped(declaration: declaration)
//                }
                
                CapsuleImageButton(title: (declaration.isFavorite ?? false) ? "heart.fill" : "heart") {
                    favoriteTapped(declaration: declaration)
                }
        
                
                if declaration.bibleVerseText != nil {
                    CapsuleImageButton(title: viewModel.showVerse ? "arrowshape.zigzag.right.fill" : "arrowshape.zigzag.forward") {
                        showVerse(declaration: declaration)
                    }
                }
                
            }
            .foregroundColor(.white)
        }
    }
    
    private func affirm(_ declaration: Declaration, isAffirmation: Bool) {
        AudioPlayerService.shared.pauseMusic()
        let text = isAffirmation ? declaration.text : declaration.bibleVerseText
        if isAffirmation {
            coordinator.speakText("Repeat after me")
        }
        coordinator.speakText(text!)
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
            print("❌ Save failed: \(error.localizedDescription)")
        } else {
            print("✅ Saved to Photos")
        }
    }
}

func shareToInstagramStories(image: UIImage) {
    // Use Photos approach for consistent behavior
    let photos = PHPhotoLibrary.shared()
    
    PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
            switch status {
            case .authorized, .limited:
                saveImageToPhotos(image: image)
            case .denied, .restricted:
                print("❌ Photos access denied")
                showPhotosPermissionAlert()
            case .notDetermined:
                print("❌ Photos permission not determined")
            @unknown default:
                print("❌ Unknown photos permission status")
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
                print("✅ Image saved to Photos")
                showImageSavedAlert()
            } else {
                print("❌ Failed to save image: \(error?.localizedDescription ?? "Unknown error")")
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


