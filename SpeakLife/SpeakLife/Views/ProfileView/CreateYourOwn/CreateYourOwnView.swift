//
//  CreateYourOwnView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 6/17/22.
//

import SwiftUI


// Wraps the entry editor's presentation state so new-entry (nil) and
// edit-entry (declaration) flows share one item-driven cover.
private struct EntrySheet: Identifiable {
    let id = UUID()
    let declaration: Declaration?
}

struct CreateYourOwnView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var syncMonitor = CloudKitSyncMonitor()
    @State private var showShareSheet = false
    @State private var entrySheet: EntrySheet?
    @State private var selectedDeclaration: Declaration?
    @State private var animate = false
    @State private var selectedContentType: ContentType = .affirmation
    @State private var forceRefresh: Int = 0
    @State private var localDeclarations: [Declaration] = []
    
    private var filteredDeclarations: [Declaration] {
        // Use local copy to avoid SwiftUI update issues
        let filtered = localDeclarations.filter { $0.contentType == selectedContentType }
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
        // Item-based presentation guarantees the tapped declaration is available
        // when the cover's content is built, so editing always opens with the
        // existing text populated on the first tap.
        .fullScreenCover(item: $entrySheet) { sheet in
            FullScreenEntryView(
                contentType: selectedContentType,
                existingText: sheet.declaration?.text ?? "",
                isEditing: sheet.declaration != nil,
                editingDeclaration: sheet.declaration
            )
            .environmentObject(declarationStore)
            .onDisappear {
                declarationStore.refreshCreateOwn()
                appState.requestReviewIfEligible(trigger: .personalDeclarationCreated)
            }
        }
        .onAppear()  {
            loadCreateOwn()
            refreshLocalDeclarations()
            AnalyticsService.shared.track(Event.createYourOwnTapped)
            
            // Force refresh in case CloudKit import happened
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        // Force single-column stack on iPad — prevents the default
        // split-view layout that leaves a black empty detail pane.
        .navigationViewStyle(.stack)
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
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.xs)
        .padding(.bottom, DS.Spacing.sm)
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
                .padding(.vertical, DS.Spacing.xs)
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
            
            VStack(spacing: DS.Spacing.xl) {
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
        VStack(spacing: DS.Spacing.xs) {
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
        ScrollView {
            LazyVStack(spacing: DS.Spacing.sm) {
                ForEach(filteredDeclarations.reversed()) { declaration in
                    declarationRow(for: declaration)
                        .padding(.horizontal, DS.Spacing.md)
                }

                listFooterSection
            }
            .padding(.top, DS.Spacing.sm)
        }
        .background(Color.clear)
    }
    
    private func declarationRow(for declaration: Declaration) -> some View {
        ContentRow(declaration, isEditable: true) { _, delete in
            handleDeclarationAction(declaration: declaration, delete: delete)
        } onSelect: {
            selectedDeclaration = declaration
        }
    }
    
    private var listFooterSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Spacer()
                AppLogo(height: 80)
                Spacer()
            }
        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, 40)
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
        Button(action: { entrySheet = EntrySheet(declaration: nil) }) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .frame(width: 30, height: 30)
                .foregroundColor(Constants.navBlue)
        }
    }
    
    // MARK: - Action Handlers
    private func handleDeclarationAction(declaration: Declaration, delete: Bool) {
        if delete {
            
            // Remove from local array immediately
            localDeclarations.removeAll { $0.id == declaration.id }
            
            // Delete from store in background
            declarationStore.removeOwn(declaration: declaration)
        } else {
            entrySheet = EntrySheet(declaration: declaration)
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
        
        
        // Remove from local array immediately to prevent UI conflicts
        for item in itemsToDelete {
            localDeclarations.removeAll { $0.id == item.id }
        }
        
        // Delete from store in background
        for item in itemsToDelete {
            declarationStore.removeOwn(declaration: item)
        }
        
    }
    
    private func refreshLocalDeclarations() {
        localDeclarations = declarationStore.createOwn
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
            entrySheet = EntrySheet(declaration: nil)
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
        .padding(.horizontal, DS.Spacing.xl)
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
                VStack(spacing: DS.Spacing.lg) {

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
                                .padding(DS.Spacing.sm)
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
                                    .padding(DS.Spacing.sm)
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
