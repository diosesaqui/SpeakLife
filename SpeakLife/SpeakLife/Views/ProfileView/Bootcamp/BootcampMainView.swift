//
//  BootcampMainView.swift
//  SpeakLife
//
//  Main view for Spiritual Warrior Bootcamp
//

import SwiftUI

struct BootcampMainView: View {
    @StateObject private var viewModel = BootcampViewModel()
    @State private var showPurchaseSheet = false
    @Namespace private var animation
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading {
                    BootcampLoadingView()
                } else if viewModel.hasAccess {
                    enrolledContent
                } else {
                    landingContent
                }
            }
            .navigationDestination(for: BootcampDestination.self) { destination in
                switch destination {
                case .lesson(let lesson):
                    LessonDetailView(lesson: lesson, viewModel: viewModel)
                case .module(let module):
                    ModuleDetailView(module: module, viewModel: viewModel)
                case .liveSession(let session):
                    LiveSessionView(session: session)
                case .challenge(let challenge):
                    ChallengeDetailView(challenge: challenge, viewModel: viewModel)
                case .resource(let resource):
                    ResourceView(resource: resource)
                }
            }
            .sheet(isPresented: $showPurchaseSheet) {
                PurchaseBootcampView(viewModel: viewModel)
            }
            .alert(item: $viewModel.error) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.localizedDescription),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Enrolled Content
    private var enrolledContent: some View {
        VStack(spacing: 0) {
            // Custom Tab Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(BootcampTab.allCases, id: \.self) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: viewModel.selectedTab == tab,
                            namespace: animation
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))
            
            // Tab Content
            Group {
                switch viewModel.selectedTab {
                case .overview:
                    BootcampOverviewTab(viewModel: viewModel)
                case .curriculum:
                    CurriculumTab(viewModel: viewModel)
                case .community:
                    CommunityTab(viewModel: viewModel)
                case .progress:
                    ProgressTab(viewModel: viewModel)
                case .resources:
                    ResourcesTab(viewModel: viewModel)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }
    
    // MARK: - Landing Content (Not Enrolled)
    private var landingContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero Section
                HeroSection(program: viewModel.currentProgram)
                    .frame(height: UIScreen.main.bounds.height * 0.5)
                
                // Program Features
                FeaturesSection()
                
                // Curriculum Preview
                CurriculumPreviewSection(program: viewModel.currentProgram)
                
                // Testimonials
                TestimonialsSection()
                
                // Pricing Section
                PricingSection(program: viewModel.currentProgram) {
                    showPurchaseSheet = true
                }
                
                // FAQ Section
                FAQSection()
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let tab: BootcampTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .medium))
                Text(tab.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                            .matchedGeometryEffect(id: "tab", in: namespace)
                    }
                }
            )
        }
    }
}

// MARK: - Hero Section
struct HeroSection: View {
    let program: BootcampProgram?
    
    var body: some View {
        ZStack {
            // Background Image with Overlay
            Image("bootcamp_hero") // Add this image to assets
                .resizable()
                .aspectRatio(contentMode: .fill)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.7),
                            Color.clear,
                            Color.black.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 24) {
                // Badge
                HStack {
                    Image(systemName: "flame.fill")
                    Text("PREMIUM PROGRAM")
                    Image(systemName: "flame.fill")
                }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        )
                )
                
                // Title
                VStack(spacing: 8) {
                    Text("SPIRITUAL WARRIOR")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    
                    Text("BOOTCAMP")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.orange)
                        .shadow(color: .orange.opacity(0.5), radius: 10)
                }
                
                // Subtitle
                Text("Transform into a victorious warrior of faith through intensive biblical training")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 40)
                
                // Stats
                HStack(spacing: 32) {
                    StatBadge(value: "12", label: "Weeks")
                    StatBadge(value: "84", label: "Lessons")
                    StatBadge(value: "500+", label: "Warriors")
                }
            }
            .padding(.top, 60)
        }
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Loading View
struct BootcampLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            Text("Loading Bootcamp...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Features Section
struct FeaturesSection: View {
    let features = [
        Feature(icon: "book.fill", title: "Biblical Foundation", description: "Deep dive into God's Word with practical application"),
        Feature(icon: "person.3.fill", title: "Community Support", description: "Connect with fellow warriors on the same journey"),
        Feature(icon: "video.fill", title: "Live Sessions", description: "Weekly live Q&A and prayer sessions"),
        Feature(icon: "medal.fill", title: "Certifications", description: "Earn certificates of completion and excellence")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What You'll Get")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(features, id: \.title) { feature in
                    FeatureCard(feature: feature)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct Feature {
    let icon: String
    let title: String
    let description: String
}

struct FeatureCard: View {
    let feature: Feature
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: feature.icon)
                .font(.system(size: 28))
                .foregroundColor(.orange)
            
            Text(feature.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(feature.description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}