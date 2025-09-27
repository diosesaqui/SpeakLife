//
//  FavoritesView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/26/22.
//

import SwiftUI
import FirebaseAnalytics

struct ContentRow: View {

    @Environment(\.colorScheme) var colorScheme
    @State private var showShareSheet = false
    @State private var isPressed = false
    @State private var shouldGlow = false

    var isEditable: Bool
    var declaration: Declaration
    var callback: ((String, _ delete: Bool) -> Void)?
    var onSelect: (() -> Void)?

    init(_ favorite: Declaration, isEditable: Bool = false, callback: ((String, Bool) -> Void)? = nil, onSelect: (() -> Void)? = nil) {
            self.declaration = favorite
            self.isEditable = isEditable
            self.callback = callback
            self.onSelect = onSelect
        }

    var body: some View {
        Button(action: handleRowTap) {
            rowContent
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(pressGesture)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            self.showShareSheet = false
        }
    }
    
    // MARK: - Private Views
    
    private var rowContent: some View {
        HStack(spacing: 12) {
            contentSection
            Spacer()
            menuButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(backgroundStyle)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(declaration.text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
            
            HStack(spacing: 4) {
                Image(systemName: declaration.contentType.icon)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(declaration.contentType.displayName)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    private var menuButton: some View {
        Image(systemName: "ellipsis.circle.fill")
            .font(.title3)
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : Constants.DAMidBlue)
            .padding(8)
            .background(Color.white.opacity(0.05))
            .clipShape(Circle())
            .contextMenu {
                contextMenuContent
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: ["\(declaration.text) \nSpeakLife App:", APP.Product.urlID])
            }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: share) {
            Label(LocalizedStringKey("Share"), systemImage: "square.and.arrow.up.fill")
        }
        
        if isEditable {
            Button(action: handleEdit) {
                Label(LocalizedStringKey("Edit"), systemImage: "pencil.circle.fill")
            }
        }
        
        Button(action: handleDelete) {
            Label(LocalizedStringKey("Delete"), systemImage: "delete.backward.fill")
        }
    }
    
    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: shouldGlow ? Color.blue.opacity(0.4) : .black.opacity(0.15),
                    radius: shouldGlow ? 10 : 8, x: 0, y: 4)
    }
    
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
    }
    
    // MARK: - Private Methods
    
    private func handleRowTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        triggerGlowAnimation()
        trackContentSelection()
        onSelect?()
    }
    
    private func triggerGlowAnimation() {
        withAnimation(.easeInOut(duration: 0.4)) {
            shouldGlow = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { shouldGlow = false }
        }
    }
    
    private func trackContentSelection() {
        Event.trackContent(
            type: declaration.contentType.rawValue,
            id: declaration.id,
            action: "selected_from_favorites",
            metadata: [
                "content_text": declaration.text,
                "is_custom": declaration.category == .myOwn
            ]
        )
    }
    
    private func handleEdit() {
        Event.trackUserAction(
            "edit_favorite",
            category: "favorites",
            metadata: ["content_type": declaration.contentType.rawValue]
        )
        edit(declaration.text)
    }
    
    private func handleDelete() {
        Event.trackUserAction(
            "delete_favorite",
            category: "favorites",
            metadata: [
                "content_type": declaration.contentType.rawValue,
                "is_custom": declaration.category == .myOwn
            ]
        )
        delete(declaration.text)
    }

    private func delete(_ declaration: String, delete: Bool = true) {
        callback?(declaration, delete)
    }

    private func share() {
        AnalyticsService.shared.trackShare(
            contentType: declaration.contentType.rawValue,
            contentId: declaration.id,
            shareMethod: "context_menu",
            metadata: [
                "source": "favorites_list",
                "content_text": declaration.text
            ]
        )
        showShareSheet = true
    }

    private func edit(_ declaration: String) {
        callback?(declaration, false)
    }
}


struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showingOptions = false
    
    
    var body: some View {
        mainContent
            .foregroundColor(foregroundColor)
            .navigationBarTitle(Text(LocalizedStringKey("Favorites")))
            .onAppear(perform: trackScreenView)
    }
    
    // MARK: - Computed Properties
    
    private var mainContent: some View {
        declarationStore.favorites.isEmpty ? AnyView(emptyStateView) : AnyView(favoritesListView)
    }
    
    private var foregroundColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .resizable()
                .frame(width: 100, height: 100)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(Constants.DAMidBlue)
            
            Text("You have no declarations favorited.", comment: "no declarations favorited")
                .font(.callout)
                .lineLimit(nil)
        }
        .padding()
    }
    
    private var favoritesListView: some View {
        ZStack {
            Gradients().speakLifeCYOCell
                .ignoresSafeArea()
            
            List {
                ForEach(declarationStore.favorites) { favorite in
                    ContentRow(favorite)
                        .onTapGesture {
                            handleFavoriteTap(favorite)
                        }
                }
                .onDelete(perform: handleDeleteFavorites)
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
            .onAppear(perform: loadFavorites)
        }
    }
    
    // MARK: - Private Methods
    
    private func trackScreenView() {
        Event.trackScreen("favorites_screen", metadata: [
            "favorites_count": declarationStore.favorites.count,
            "has_favorites": !declarationStore.favorites.isEmpty
        ])
    }
    
    private func handleFavoriteTap(_ favorite: Declaration) {
        withAnimation {
            declarationStore.choose(favorite)
            popToRoot()
        }
    }
    
    private func handleDeleteFavorites(at offsets: IndexSet) {
        for index in offsets {
            if index < declarationStore.favorites.count {
                let favorite = declarationStore.favorites[index]
                trackDeleteAction(for: favorite)
            }
        }
        declarationStore.removeFavorite(at: offsets)
    }
    
    private func trackDeleteAction(for favorite: Declaration) {
        Event.trackUserAction(
            "swipe_delete_favorite",
            category: "favorites",
            metadata: [
                "content_type": favorite.contentType.rawValue,
                "is_custom": favorite.category == .myOwn
            ]
        )
    }
    
    private func popToRoot() {
        appState.rootViewId = UUID()
    }
    
    private func loadFavorites() {
        declarationStore.refreshFavorites()
    }
}


