//
//  CreateYourOwnView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 6/17/22.
//

import SwiftUI
import FirebaseAnalytics



struct CreateYourOwnView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var syncMonitor = CloudKitSyncMonitor()
    @State private var showShareSheet = false
    @State private var showFullScreenEntry = false
    @State private var editingDeclaration: Declaration?
    @State private var selectedDeclaration: Declaration?
    @State private var animate = false
    @State private var selectedContentType: ContentType = .affirmation
    @State private var forceRefresh: Int = 0
    @State private var localDeclarations: [Declaration] = []
    
    private var filteredDeclarations: [Declaration] {
        // Use local copy to avoid SwiftUI update issues
        let filtered = localDeclarations.filter { $0.contentType == selectedContentType }
        print("RWRW: Filtered declarations count: \(filtered.count) for type: \(selectedContentType)")
        return filtered
    }
    
    private var emptyStateTitle: String {
        switch selectedContentType {
        case .affirmation:
            return "You're just one affirmation away\nfrom breakthrough."
        case .journal:
            return "Start your spiritual journey\nwith journaling."
        }
    }
    
    private var emptyStateSubtitle: String {
        switch selectedContentType {
        case .affirmation:
            return "Speak what God says. See what God promised."
        case .journal:
            return "Record God's faithfulness and your growth."
        }
    }
    
    var body: some View {
        ZStack {
            configureView()
            
        }
        .fullScreenCover(isPresented: $showFullScreenEntry) {
            FullScreenEntryView(
                contentType: selectedContentType,
                existingText: editingDeclaration?.text ?? "",
                isEditing: editingDeclaration != nil,
                editingDeclaration: editingDeclaration
            )
            .environmentObject(declarationStore)
            .onDisappear {
                editingDeclaration = nil
                declarationStore.refreshCreateOwn()
                declarationStore.requestReview.toggle()
            }
        }
        .onAppear()  {
            loadCreateOwn()
            refreshLocalDeclarations()
            Analytics.logEvent(Event.createYourOwnTapped, parameters: nil)
            
            // Force refresh in case CloudKit import happened
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("RWRW: CreateYourOwnView onAppear - forcing data refresh")
                declarationStore.fetchDeclarations(for: .myOwn) { decs in
                    self.refreshLocalDeclarations()
                }
            }
        }
        .onChange(of: declarationStore.createOwn) { _ in
            refreshLocalDeclarations()
        }
    }
    
    @ViewBuilder
    func configureView() -> some View {
        NavigationView {
            VStack(spacing: 0) {
                segmentedControlView
                contentAreaView
            }
            .background(backgroundGradient)
            .navigationTitle(selectedContentType.pluralDisplayName)
            .toolbar { toolbarContent }
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Constants.SLBlue.opacity(0.8), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // MARK: - Background Components
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.15, blue: 0.3),
                Color(red: 0.08, green: 0.12, blue: 0.25)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Segmented Control Components
    private var segmentedControlView: some View {
        HStack(spacing: 0) {
            ForEach(ContentType.allCases, id: \.self) { contentType in
                segmentedControlButton(for: contentType)
            }
        }
        .padding(2)
        .background(segmentedControlBackground)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    private func segmentedControlButton(for contentType: ContentType) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedContentType = contentType
            }
        }) {
            Text(contentType.pluralDisplayName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(selectedContentType == contentType ? .white : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(segmentedControlButtonBackground(for: contentType))
                .animation(.easeInOut(duration: 0.2), value: selectedContentType)
        }
    }
    
    private func segmentedControlButtonBackground(for contentType: ContentType) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(selectedContentType == contentType ? 
                .white.opacity(0.1) :
                  Color.clear)
    }
    
    private var segmentedControlBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Constants.SLBlue.opacity(0.2))
            .shadow(color: Constants.SLBlue.opacity(0.4), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Content Area Components
    @ViewBuilder
    private var contentAreaView: some View {
        if filteredDeclarations.isEmpty {
            emptyStateView
                .transition(.opacity.combined(with: .scale))
        } else {
            declarationsListView
                .transition(.opacity)
        }
    }
    
    // MARK: - Empty State Components
    private var emptyStateView: some View {
        ZStack {
            Gradients().speakLifeCYOCell
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer().frame(height: 40)
                animatedLogoView
                emptyStateTextContent
                addAffirmationsButton
                Spacer()
            }
            .onAppear { animate = true }
        }
    }
    
    private var animatedLogoView: some View {
        ZStack {
            Circle()
                .fill(Constants.DAMidBlue.opacity(0.15))
                .frame(width: 170, height: 170)
                .scaleEffect(animate ? 1.1 : 1)
                .opacity(animate ? 0.8 : 0.3)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: animate)
            
            AppLogo(height: 100)
        }
    }
    
    private var emptyStateTextContent: some View {
        VStack(spacing: 8) {
            Text(emptyStateTitle)
                .font(.system(size: 20, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.3), value: selectedContentType)
            
            Text(emptyStateSubtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .animation(.easeInOut(duration: 0.3), value: selectedContentType)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Declarations List Components
    private var declarationsListView: some View {
        ZStack {
            Gradients().speakLifeCYOCell
                .ignoresSafeArea()
            
            declarationsList
            hiddenNavigationLink
        }
    }
    
    private var declarationsList: some View {
        List {
            ForEach(filteredDeclarations.reversed()) { declaration in
                declarationRow(for: declaration)
            }
            // Remove .onDelete completely to avoid SwiftUI collection view issues
            
            listFooterSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .id("declarations-\(forceRefresh)")
    }
    
    private func declarationRow(for declaration: Declaration) -> some View {
        ContentRow(declaration, isEditable: true) { _, delete in
            handleDeclarationAction(declaration: declaration, delete: delete)
        } onSelect: {
            selectedDeclaration = declaration
        }
        .listRowBackground(Color.clear)
    }
    
    private var listFooterSection: some View {
        Section {
            VStack(spacing: 12) {
                
                HStack {
                    Spacer()
                    AppLogo(height: 80)
                    Spacer()
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    private var hiddenNavigationLink: some View {
        NavigationLink(
            destination: AffirmationDetailView(affirmation: selectedDeclaration ?? declarationStore.createOwn.first!),
            isActive: Binding(
                get: { selectedDeclaration != nil },
                set: { if !$0 { selectedDeclaration = nil } }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }
    
    // MARK: - Toolbar Components
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            CloudKitSyncBadgeCompact(syncMonitor: syncMonitor)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            if !filteredDeclarations.isEmpty {
                addButton
            }
        }
    }
    
    private var addButton: some View {
        Button(action: { showFullScreenEntry = true }) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .frame(width: 30, height: 30)
                .foregroundColor(Constants.navBlue)
        }
    }
    
    // MARK: - Action Handlers
    private func handleDeclarationAction(declaration: Declaration, delete: Bool) {
        if delete {
            print("RWRW: Handling declaration delete for: \(declaration.text.prefix(20))")
            
            // Remove from local array immediately
            localDeclarations.removeAll { $0.id == declaration.id }
            print("RWRW: Local declarations after delete: \(localDeclarations.count)")
            
            // Delete from store in background
            declarationStore.removeOwn(declaration: declaration)
        } else {
            editingDeclaration = declaration
            showFullScreenEntry = true
        }
    }
    
    private func deleteDeclarations(at indexSet: IndexSet) {
        let displayedDeclarations = Array(filteredDeclarations.reversed())
        
        // Collect items to delete first
        var itemsToDelete: [Declaration] = []
        for index in indexSet {
            if index < displayedDeclarations.count {
                itemsToDelete.append(displayedDeclarations[index])
            }
        }
        
        print("RWRW: Deleting \(itemsToDelete.count) items from UI")
        
        // Remove from local array immediately to prevent UI conflicts
        for item in itemsToDelete {
            localDeclarations.removeAll { $0.id == item.id }
        }
        
        // Delete from store in background
        for item in itemsToDelete {
            declarationStore.removeOwn(declaration: item)
        }
        
        print("RWRW: Local declarations updated, count: \(localDeclarations.count)")
    }
    
    private func refreshLocalDeclarations() {
        localDeclarations = declarationStore.createOwn
        print("RWRW: Local declarations refreshed, count: \(localDeclarations.count)")
    }
    
    
    
    private func edit(_ declaration: String) {
        // This method is no longer used - editing is handled through the full-screen view
    }
    
    private func spacerView(_ height:  CGFloat)  -> some View  {
        Spacer()
            .frame(height: height)
    }
    
    private var addAffirmationsButton: some View {
        Button(action: {
            showFullScreenEntry = true
        }) {
            Text("Create your own")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Constants.DAMidBlue)
                .cornerRadius(14)
                .shadow(color: Constants.DAMidBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                .scaleEffect(1.02)
        }
        .padding(.horizontal, 32)
    }
    
    
    private func popToRoot()  {
        appState.rootViewId = UUID()
    }
    
    private func loadCreateOwn()  {
        declarationStore.refreshCreateOwn()
    }
}

struct TextViewWrapper: UIViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextViewWrapper
        
        init(_ parent: TextViewWrapper) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
    
    func makeUIView(context: Context) -> UITextView {
        let font = UIFont.systemFont(ofSize: 20, weight: .medium)
        let roundedFont = UIFont(descriptor: font.fontDescriptor.withDesign(.rounded)!, size: 20)
        let textView = UITextView()
        textView.backgroundColor = .white
        textView.textColor = .black
        textView.layer.cornerRadius = 4
        textView.font = roundedFont
        textView.delegate = context.coordinator
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
}

struct CreateYourOwnView_Previews: PreviewProvider {
    static var previews: some View {
        CreateYourOwnView()
            .environmentObject(DeclarationViewModel(apiService: LocalAPIClient()))
            .environmentObject(AppState())
        
    }
}



struct AffirmationDetailView: View {
    let affirmation: Declaration // Replace with your model
    
    @State private var displayedText = ""
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @State var animateGlow = false
    @State private var showCursor = true
    @State private var showCreateYourOwn = false
    
    
    var body: some View {
            ZStack() {
                // Background
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea()
                
                // Pulsing Glow
                Circle()
                    .fill(Constants.DAMidBlue.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 40)
                    .scaleEffect(animateGlow ? 1.05 : 1)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateGlow)
                    .offset(y: -100)
                
                // Content
                VStack(spacing: 20) {
                    
                    Text(affirmation.lastEdit?.toPrettyString() ?? "")
                        .font(.subheadline)
                        .foregroundColor(Color.gray)
                        .padding(.top, 40)
                    
                    if showCreateYourOwn {
                        Text("Create Your Own")
                            .foregroundColor(Color.gray)
                            .font(.title3)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    ZStack(alignment: .topLeading) {
                       
                        if showCursor {
                            VStack {
                            Text(displayedText + "|")
                                .font(.system(size: dynamicFontSize, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(0.9)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                        .shadow(color: Color.white.opacity(0.1), radius: 6)
                                )
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: showCursor)
                            Spacer()
                                .frame(height: UIScreen.main.bounds.height * 0.1)
                            AppLogo(height: 80)
                        }
                        } else {
                            VStack {
                                Text(displayedText)
                                    .font(.system(size: dynamicFontSize, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(12)
                                Spacer()
                                    .frame(height: UIScreen.main.bounds.height * 0.1)
                                AppLogo(height: 80)
                            }
                        }
                    }
                    Spacer()
                }
            }

        .onAppear {
            timer?.invalidate()
            displayedText = ""
            showCursor = true
            startTypingAnimation()
            animateGlow = true
            showCreateYourOwn = true
        }
    }
    
    private func startTypingAnimation() {
        let affirmation = affirmation.text
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard displayedText.count < affirmation.count else {
                timer?.invalidate()
                timer = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showCursor = false }
                }
                return
            }
            
            let nextChar = affirmation[affirmation.index(affirmation.startIndex, offsetBy: displayedText.count)]
            displayedText.append(nextChar)
        }
    }
    
    private var dynamicFontSize: CGFloat {
        switch affirmation.text.count {
        case 0..<100: return 28
        case 100..<160: return 24
        default: return 20
        }
    }
    
    private func textWidth(_ text: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: dynamicFontSize, weight: .bold)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return size.width
    }
}
