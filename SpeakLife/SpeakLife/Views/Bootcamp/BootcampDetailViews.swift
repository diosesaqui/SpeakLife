//
//  BootcampDetailViews.swift
//  SpeakLife
//
//  Detail views for Bootcamp components
//

import SwiftUI

// MARK: - Lesson Detail View
struct LessonDetailView: View {
    let lesson: Lesson
    @ObservedObject var viewModel: BootcampViewModel
    @State private var showReflection = false
    @State private var reflectionText = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Lesson Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: lesson.type.icon)
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Day \(lesson.dayNumber)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text("\(lesson.duration) min")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text(lesson.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                
                // Main Content Area
                if lesson.type == .video {
                    VideoPlayerPlaceholder()
                } else if lesson.type == .audio {
                    AudioPlayerPlaceholder()
                } else {
                    ReadingContentPlaceholder()
                }
                
                // Key Points
                if !lesson.content.keyPoints.isEmpty {
                    KeyPointsSection(points: lesson.content.keyPoints)
                }
                
                // Scripture References
                if !lesson.content.scriptureReferences.isEmpty {
                    ScriptureSection(references: lesson.content.scriptureReferences)
                }
                
                // Action Steps
                if !lesson.content.actionSteps.isEmpty {
                    ActionStepsSection(steps: lesson.content.actionSteps)
                }
                
                // Reflection Prompt
                if let reflection = lesson.reflection {
                    ReflectionSection(
                        prompt: reflection,
                        reflectionText: $reflectionText,
                        onSubmit: {
                            Task {
                                await viewModel.submitReflection(reflectionText)
                            }
                        }
                    )
                }
                
                // Complete Lesson Button
                Button(action: {
                    Task {
                        await viewModel.completeLesson(lesson.id)
                    }
                }) {
                    HStack {
                        Image(systemName: lesson.isCompleted ? "checkmark.circle.fill" : "circle")
                        Text(lesson.isCompleted ? "Completed" : "Mark as Complete")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(lesson.isCompleted ? Color.green : Color.blue)
                    )
                }
                .padding(.horizontal)
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Module Detail View
struct ModuleDetailView: View {
    let module: BootcampModule
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Module Header
                ModuleHeaderView(module: module)
                
                // Weekly Challenge
                if module.isUnlocked {
                    WeeklyChallengeCard(challenge: module.weeklyChallenge, viewModel: viewModel)
                }
                
                // Lessons List
                VStack(alignment: .leading, spacing: 16) {
                    Text("Lessons")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(module.lessons) { lesson in
                        LessonRow(lesson: lesson) {
                            Task {
                                await viewModel.startLesson(lesson)
                            }
                        }
                        .disabled(!module.isUnlocked)
                    }
                }
                .padding()
                
                // Live Session Info
                if let liveSession = module.liveSession {
                    LiveSessionCard(session: liveSession, viewModel: viewModel)
                }
            }
        }
        .background(Color.black)
        .navigationTitle("Week \(module.weekNumber)")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Live Session View
struct LiveSessionView: View {
    let session: LiveSession
    
    var body: some View {
        VStack(spacing: 20) {
            Text(session.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Session details
            VStack(alignment: .leading, spacing: 12) {
                Label(session.scheduledDate.formatted(), systemImage: "calendar")
                Label("\(session.duration) minutes", systemImage: "clock")
                
                if let zoomLink = session.zoomLink {
                    Button(action: {
                        // Open Zoom link
                    }) {
                        Label("Join Session", systemImage: "video.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - Challenge Detail View
struct ChallengeDetailView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(challenge.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(challenge.description)
                    .foregroundColor(.white.opacity(0.8))
                
                // Objectives
                VStack(alignment: .leading, spacing: 12) {
                    Text("Objectives")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(challenge.objectives) { objective in
                        ObjectiveRow(objective: objective)
                    }
                }
                
                // Reward
                RewardCard(reward: challenge.reward)
            }
            .padding()
        }
        .background(Color.black)
    }
}

// MARK: - Resource View
struct ResourceView: View {
    let resource: Resource
    
    var body: some View {
        VStack {
            Text(resource.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            // Resource content placeholder
            Text("Resource content would appear here")
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - Purchase View
struct PurchaseBootcampView: View {
    @ObservedObject var viewModel: BootcampViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Program Details
                    if let program = viewModel.currentProgram {
                        ProgramPurchaseCard(program: program)
                        
                        // Payment Options
                        PaymentOptionsSection(program: program)
                        
                        // Purchase Button
                        Button(action: {
                            Task {
                                await viewModel.purchaseBootcamp()
                                dismiss()
                            }
                        }) {
                            Text("Enroll Now")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.black)
            .navigationTitle("Enroll in Bootcamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Landing Page Sections

struct CurriculumPreviewSection: View {
    let program: BootcampProgram?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Curriculum Preview")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            if let program = program {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(program.modules.prefix(4))) { module in
                            CurriculumPreviewCard(module: module)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct TestimonialsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What Warriors Are Saying")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            // Placeholder testimonials
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        BootcampTestimonialCard()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct PricingSection: View {
    let program: BootcampProgram?
    let onPurchase: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Investment in Your Spiritual Growth")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let program = program {
                PricingCard(price: program.price, onPurchase: onPurchase)
            }
        }
        .padding()
    }
}

struct FAQSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Frequently Asked Questions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Placeholder FAQs
            VStack(spacing: 12) {
                FAQItem(question: "How long do I have access?", answer: "Lifetime access to all materials")
                FAQItem(question: "What if I fall behind?", answer: "Go at your own pace with full support")
                FAQItem(question: "Is there a money-back guarantee?", answer: "30-day satisfaction guarantee")
            }
        }
        .padding()
    }
}

// MARK: - Supporting Components

struct VideoPlayerPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.1))
            .frame(height: 200)
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.5))
            )
            .padding(.horizontal)
    }
}

struct AudioPlayerPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.1))
            .frame(height: 120)
            .overlay(
                Image(systemName: "headphones")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.5))
            )
            .padding(.horizontal)
    }
}

struct ReadingContentPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading content would appear here")
                .foregroundColor(.white.opacity(0.7))
                .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .padding(.horizontal)
    }
}

struct KeyPointsSection: View {
    let points: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Points")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(points, id: \.self) { point in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(point)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding()
    }
}

struct ScriptureSection: View {
    let references: [ScriptureReference]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scripture References")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(references) { reference in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(reference.book) \(reference.chapter):\(reference.verses)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text(reference.text)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .italic()
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct ActionStepsSection: View {
    let steps: [ActionStep]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Action Steps")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(steps) { step in
                HStack {
                    Image(systemName: step.isCompleted ? "checkmark.square.fill" : "square")
                        .foregroundColor(step.isCompleted ? .green : .white.opacity(0.5))
                    Text(step.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text("+\(step.points) pts")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
    }
}

struct ReflectionSection: View {
    let prompt: ReflectionPrompt
    @Binding var reflectionText: String
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reflection")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(prompt.question)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            TextEditor(text: $reflectionText)
                .frame(height: 100)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            
            Button(action: onSubmit) {
                Text("Submit Reflection")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct ModuleHeaderView: View {
    let module: BootcampModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: module.phase.icon)
                    .font(.title)
                    .foregroundColor(module.phase.color)
                Text(module.phase.displayName)
                    .font(.caption)
                    .foregroundColor(module.phase.color)
            }
            
            Text(module.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(module.description)
                .foregroundColor(.white.opacity(0.8))
            
            Text(module.scripture)
                .font(.caption)
                .italic()
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(Color.white.opacity(0.1))
    }
}

struct WeeklyChallengeCard: View {
    let challenge: WeeklyChallenge
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        Button(action: {
            viewModel.navigationPath.append(BootcampDestination.challenge(challenge))
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.orange)
                    Text("Weekly Challenge")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if challenge.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Text(challenge.title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.2))
            )
        }
        .padding(.horizontal)
    }
}

struct LessonRow: View {
    let lesson: Lesson
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: lesson.type.icon)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("Day \(lesson.dayNumber) • \(lesson.duration) min")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if lesson.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
}

struct LiveSessionCard: View {
    let session: LiveSession
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        Button(action: {
            viewModel.navigationPath.append(BootcampDestination.liveSession(session))
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "video.fill")
                        .foregroundColor(.blue)
                    Text("Live Session")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text(session.title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Label(session.scheduledDate.formatted(), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.2))
            )
        }
        .padding(.horizontal)
    }
}

struct ObjectiveRow: View {
    let objective: ChallengeObjective
    
    var body: some View {
        HStack {
            Image(systemName: objective.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(objective.isCompleted ? .green : .white.opacity(0.5))
            
            Text(objective.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            if let target = objective.targetCount {
                Text("\(objective.currentCount)/\(target)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct RewardCard: View {
    let reward: ChallengeReward
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reward")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.yellow)
                Text(reward.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.2))
        )
    }
}

struct ProgramPurchaseCard: View {
    let program: BootcampProgram
    
    var body: some View {
        VStack(spacing: 16) {
            Text(program.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(program.subtitle)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 20) {
                Label("\(program.duration.weeks) weeks", systemImage: "calendar")
                Label("\(program.modules.count) modules", systemImage: "book.closed")
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding()
    }
}

struct PaymentOptionsSection: View {
    let program: BootcampProgram
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Options")
                .font(.headline)
                .foregroundColor(.white)
            
            // One-time payment
            VStack(alignment: .leading, spacing: 8) {
                Text("One-Time Payment")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(program.price.displayPrice)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            // Payment plans
            ForEach(program.price.paymentPlans) { plan in
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.name)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("\(plan.installments) payments of $\(plan.amountPerInstallment, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
}

struct CurriculumPreviewCard: View {
    let module: BootcampModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Week \(module.weekNumber)")
                .font(.caption)
                .foregroundColor(module.phase.color)
            
            Text(module.title)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text("\(module.lessons.count) lessons")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct BootcampTestimonialCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\"This bootcamp transformed my spiritual life completely.\"")
                .font(.subheadline)
                .italic()
                .foregroundColor(.white.opacity(0.9))
            
            HStack {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading) {
                    Text("John D.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Completed Week 12")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .frame(width: 250)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct PricingCard: View {
    let price: Price
    let onPurchase: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Original price with strikethrough if discounted
            if let originalAmount = price.originalAmount {
                Text("$\(originalAmount, specifier: "%.0f")")
                    .font(.title3)
                    .strikethrough()
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(price.displayPrice)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Button(action: onPurchase) {
                Text("Enroll Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            
            Text("30-day money-back guarantee")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}
