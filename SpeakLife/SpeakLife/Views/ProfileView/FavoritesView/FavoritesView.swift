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
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.4)) {
                shouldGlow = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { shouldGlow = false }
            }
            onSelect?()
        }) {
            HStack(spacing: 12) {
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

                Spacer()

                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : Constants.DAMidBlue)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
                    .contextMenu {
                        Button(action: share) {
                            Label(LocalizedStringKey("Share"), systemImage: "square.and.arrow.up.fill")
                        }

                        if isEditable {
                            Button {
                                edit(declaration.text)
                            } label: {
                                Label(LocalizedStringKey("Edit"), systemImage: "pencil.circle.fill")
                            }
                        }

                        Button {
                            delete(declaration.text)
                        } label: {
                            Label(LocalizedStringKey("Delete"), systemImage: "delete.backward.fill")
                        }
                    }
                    .sheet(isPresented: $showShareSheet) {
                        ShareSheet(activityItems: ["\(declaration.text) \nSpeakLife App:", APP.Product.urlID])
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: shouldGlow ? Color.blue.opacity(0.4) : .black.opacity(0.15),
                            radius: shouldGlow ? 10 : 8, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPressed = false
                    }
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            self.showShareSheet = false
        }
    }

    func delete(_ declaration: String, delete: Bool = true) {
        callback?(declaration, delete)
    }

    private func share() {
        showShareSheet = true
    }

    func edit(_ declaration: String) {
        callback?(declaration, false)
    }
}


struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showingOptions = false
    
    
    var body: some View {
        configureView()
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .navigationBarTitle(Text(LocalizedStringKey("Favorites")))
        
    }
    
    @ViewBuilder
    func configureView() -> some View  {
        if declarationStore.favorites.isEmpty {
            VStack {
                
                Image(systemName: "heart.text.square")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Constants.DAMidBlue)
                
                Spacer()
                    .background(Color.clear)
                    .frame(height: 16)
                
                Text("You have no declarations favorited.", comment: "no declarations favorited")
                    .font(.callout)
                    .lineLimit(nil)
                
                
                
            }.padding()
            
        } else {
            ZStack {
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea()
                List {
                    ForEach(declarationStore.favorites) { favorite in
                        ContentRow(favorite)
                            .onTapGesture {
                                withAnimation {
                                    declarationStore.choose(favorite)
                                    popToRoot()
                                }
                                
                            }
                    }
                    .onDelete { offsets in
                        declarationStore.removeFavorite(at: offsets)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(.clear)
                .onAppear()  {
                    loadFavorites()
                }
            }
        }
            
    }
    
    private func popToRoot()  {
        appState.rootViewId = UUID()
    }
    
    
    private func loadFavorites() {
        declarationStore.refreshFavorites()
    }
}


