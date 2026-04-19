# Personal Declaration Feature Spec
### "Believe for One Thing"
**Version:** 1.0 — MVP  
**Status:** Ready for development  
**Author:** SpeakLife AI Chief of Staff

---

## Overview

A new onboarding step and persistent in-app feature where the user declares one specific thing they are trusting God for. The app matches their declaration to a curated Bible verse and personalized declaration text. This becomes their daily anchor — spoken every day until it comes to pass.

**Why this matters:**
- Creates personal investment at the highest-stakes moment (before paywall)
- Turns the paywall pitch from "get unlimited content" to "we'll remind you of this every day until God comes through"
- Creates a daily return habit tied to meaning, not just habit loops
- Foundation for future testimony / breakthrough feature

---

## Onboarding Flow

```
Survey → Personal Declaration → Paywall → Notifications → App
```

**Reasoning:** Personal Declaration creates the emotional peak. Paywall immediately follows at the user's highest investment moment. Notification setup is then framed around their specific declaration, not generic reminders.

### Tab Enum Update — `OnboardingTypes.swift`

```swift
enum Tab: String {
    case survey
    case personalDeclaration  // ← new
    case subscription
    case notification
    // legacy A/B tabs preserved below
    case emotionalHook
    case categorySelect
    case livePreview
    case socialProof
    case dailyCommitment
}
```

### Navigation Update — `OnboardingView.swift` `advance()`

```swift
case .survey:
    selection = .personalDeclaration

case .personalDeclaration:
    selection = .subscription

case .subscription:
    selection = .notification

case .notification:
    dismissOnboarding()
```

### Paywall Copy Update

Pass the matched declaration into the paywall so it can show personalized copy:

```swift
// If personal declaration exists, show:
"You just declared what you're trusting God for.
 SpeakLife sends you this declaration every day until it comes to pass."

// Falls back to survey-based copy if skipped
```

### Notification Screen Copy Update

Change the time picker framing to:
> *"When do you want to receive your personal declaration every day?"*

---

## Architecture

Follows SOLID principles with strict layer separation. No business logic in Views. All dependencies injected via protocols.

```
View
  └── ViewModel (@MainActor, ObservableObject)
        ├── Use Cases (single-responsibility business logic)
        │     ├── MatchDeclarationUseCase
        │     ├── SavePersonalDeclarationUseCase
        │     └── MarkDeclarationReceivedUseCase
        ├── Repository (persistence abstraction)
        │     └── PersonalDeclarationRepository (UserDefaults — MVP)
        └── Services (external concerns)
              ├── SpeechTranscriptionService
              └── DeclarationNotificationService
```

---

## Data Model

**File:** `Models/PersonalDeclaration.swift`

```swift
struct PersonalDeclaration: Codable, Equatable {
    let id: UUID
    let beliefText: String           // raw text from user (transcribed or typed)
    let declarationText: String      // matched declaration
    let verse: String                // matched Bible verse text
    let verseReference: String       // e.g. "Jeremiah 29:11"
    let categoryRaw: String          // DeclarationCategory rawValue
    let startDate: Date
    var receivedDate: Date?
    var testimony: String?

    var isReceived: Bool { receivedDate != nil }

    var dayCount: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0 + 1)
    }

    var category: DeclarationCategory? {
        DeclarationCategory(rawValue: categoryRaw)
    }
}
```

**`AppState.swift` — add one property:**

```swift
@AppStorage("hasPersonalDeclaration") var hasPersonalDeclaration: Bool = false
```

That's all AppState needs. The full declaration object lives in the repository.

---

## Storage — MVP Decision

**Use `UserDefaults` for MVP.** It's one record for one user. No queries, no relationships, no history needed yet.

**Migration path (v2 — when you add testimonies history):**
1. Create `PersonalDeclarationEntity` in CoreData
2. Implement `CoreDataPersonalDeclarationRepository` conforming to same protocol
3. One-time migration: pull UserDefaults record into CoreData on first launch after update
4. Change one line in `DIContainer` — nothing else changes

---

## Protocols

**Directory:** `Services/PersonalDeclaration/Protocols/`

All async since repository may eventually become CloudKit-backed.

```swift
// DeclarationMatcherProtocol.swift
protocol DeclarationMatcherProtocol {
    func match(input: String) -> DeclarationMatch
}

// SpeechTranscriptionProtocol.swift
protocol SpeechTranscriptionProtocol {
    var isRecording: Bool { get }
    func requestPermission() async -> Bool
    func startRecording() async throws
    func stopRecording() async -> String  // returns transcribed text
}

// PersonalDeclarationRepositoryProtocol.swift
protocol PersonalDeclarationRepositoryProtocol {
    func save(_ declaration: PersonalDeclaration) async throws
    func load() async -> PersonalDeclaration?
    func markReceived(id: UUID, testimony: String?) async throws
    func clear() async throws
}

// DeclarationNotificationServiceProtocol.swift
protocol DeclarationNotificationServiceProtocol {
    func schedule(for declaration: PersonalDeclaration)
    func cancel()
}
```

---

## Services

### Matching

**File:** `Services/PersonalDeclaration/DeclarationMatcher.swift`

```swift
struct DeclarationMatch {
    let category: DeclarationCategory
    let declarationText: String
    let verse: String
    let verseReference: String
}

// Open for extension (new rules), closed for modification
struct MatchRule {
    let keywords: [String]
    let category: DeclarationCategory

    static let defaults: [MatchRule] = [
        MatchRule(keywords: ["heal", "sick", "health", "body", "cancer", "pain", "disease", "recover"], category: .health),
        MatchRule(keywords: ["job", "money", "financ", "debt", "provid", "business", "wealth", "income", "broke"], category: .wealth),
        MatchRule(keywords: ["anxiety", "anxious", "fear", "panic", "worry", "stress", "overwhelm"], category: .anxiety),
        MatchRule(keywords: ["marriage", "husband", "wife", "spouse", "relationship", "divorce"], category: .marriage),
        MatchRule(keywords: ["child", "son", "daughter", "parent", "kids", "family"], category: .parenting),
        MatchRule(keywords: ["purpose", "calling", "destiny", "direction", "lost", "confus"], category: .destiny),
        MatchRule(keywords: ["identity", "worth", "enough", "value", "belong"], category: .identity),
        MatchRule(keywords: ["peace", "rest", "sleep", "calm"], category: .rest),
        MatchRule(keywords: ["joy", "happy", "depress", "sad", "grief", "mourn"], category: .joy),
        MatchRule(keywords: ["favor", "door", "opportunit", "promot"], category: .favor),
        MatchRule(keywords: ["forgiv", "guilt", "shame", "past", "mistake"], category: .grace),
        MatchRule(keywords: ["protect", "safe", "danger"], category: .godsprotection),
        MatchRule(keywords: ["addict", "substance", "alcohol", "porn", "habit"], category: .addiction),
    ]
}

final class KeywordDeclarationMatcher: DeclarationMatcherProtocol {
    private let rules: [MatchRule]

    init(rules: [MatchRule] = MatchRule.defaults) {
        self.rules = rules
    }

    func match(input: String) -> DeclarationMatch {
        let lower = input.lowercased()
        let category = rules.first(where: { rule in
            rule.keywords.contains(where: { lower.contains($0) })
        })?.category ?? .faith

        return DeclarationMatch(
            category: category,
            declarationText: DeclarationContent.declaration(for: category),
            verse: DeclarationContent.verse(for: category),
            verseReference: DeclarationContent.verseReference(for: category)
        )
    }
}
```

**File:** `Services/PersonalDeclaration/DeclarationContent.swift`

```swift
// Separated from matching logic (Single Responsibility)
enum DeclarationContent {

    static func verse(for category: DeclarationCategory) -> String {
        switch category {
        case .health:        return "\"I am the Lord who heals you.\""
        case .wealth:        return "\"My God will supply every need of yours according to his riches in glory.\""
        case .anxiety:       return "\"Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.\""
        case .marriage:      return "\"What God has joined together, let no one separate.\""
        case .parenting:     return "\"Train up a child in the way he should go; even when he is old he will not depart from it.\""
        case .destiny:       return "\"For I know the plans I have for you — plans to prosper you and not to harm you, plans to give you hope and a future.\""
        case .identity:      return "\"You are a chosen people, a royal priesthood, a holy nation, God's special possession.\""
        case .rest:          return "\"You will keep in perfect peace those whose minds are steadfast, because they trust in you.\""
        case .joy:           return "\"The joy of the Lord is your strength.\""
        case .favor:         return "\"For surely, O Lord, you bless the righteous; you surround them with your favor as with a shield.\""
        case .grace:         return "\"There is now no condemnation for those who are in Christ Jesus.\""
        case .godsprotection:return "\"The Lord will fight for you; you need only to be still.\""
        case .addiction:     return "\"I can do all things through Christ who strengthens me.\""
        default:             return "\"Being confident of this, that he who began a good work in you will carry it on to completion.\""
        }
    }

    static func verseReference(for category: DeclarationCategory) -> String {
        switch category {
        case .health:        return "Exodus 15:26"
        case .wealth:        return "Philippians 4:19"
        case .anxiety:       return "Philippians 4:6"
        case .marriage:      return "Matthew 19:6"
        case .parenting:     return "Proverbs 22:6"
        case .destiny:       return "Jeremiah 29:11"
        case .identity:      return "1 Peter 2:9"
        case .rest:          return "Isaiah 26:3"
        case .joy:           return "Nehemiah 8:10"
        case .favor:         return "Psalm 5:12"
        case .grace:         return "Romans 8:1"
        case .godsprotection:return "Exodus 14:14"
        case .addiction:     return "Philippians 4:13"
        default:             return "Philippians 1:6"
        }
    }

    static func declaration(for category: DeclarationCategory) -> String {
        switch category {
        case .health:
            return "I declare that I am healed by the stripes of Jesus. My body is the temple of the Holy Spirit and every cell aligns with God's perfect design. Healing is mine — I receive it now and every day until I see it fully manifest."
        case .wealth:
            return "I declare that God is my provider and my source. Every need is met. Every door He ordained is open. I walk in overflow, not lack, and I will see His provision manifest in my life."
        case .anxiety:
            return "I declare that the peace that surpasses all understanding guards my heart and mind. Fear has no place in me. I cast every care on the Lord and I trust that He holds every detail of my life."
        case .marriage:
            return "I declare that my marriage is covered by the blood of Jesus. What God has joined, no force can break. Love, patience, and covenant define this relationship and we grow stronger every day."
        case .parenting:
            return "I declare that my children are taught by the Lord and great is their peace. Every child in my home is covered, called, and walking in their God-given destiny. I am the parent God chose for them."
        case .destiny:
            return "I declare that I will walk fully in the purpose God wrote for me before the foundation of the world. Every gift is awakened. Every assignment is clear. I will not leave this earth without fulfilling my calling."
        case .identity:
            return "I declare that I know who I am. I am chosen, loved, and called. My identity is not in what I've done or what others say — it is rooted in who God says I am, and that does not change."
        case .rest:
            return "I declare that God's perfect peace rules my mind today and every day. I am not moved by what I see. I am anchored in the truth of His Word and I rest in the finished work of Jesus."
        case .joy:
            return "I declare that the joy of the Lord is my strength. No season, no loss, no circumstance can steal what God has placed inside me. I choose joy and it grows stronger in me every single day."
        case .favor:
            return "I declare that God's favor surrounds me like a shield. Doors open for me that no man can shut. I am seen, promoted, and positioned by the Lord in every room I walk into."
        case .grace:
            return "I declare that I am free from condemnation. My past does not define me — the blood of Jesus does. I walk in grace today and every day, fully forgiven and fully restored."
        case .godsprotection:
            return "I declare that I and everyone I love are covered by the protection of God Almighty. No weapon formed against us shall prosper. Angels surround us and the Lord fights every battle."
        case .addiction:
            return "I declare that I am free. The chains are broken and I walk in the liberty that Christ purchased for me. I am not defined by what once held me — I am defined by who holds me now."
        default:
            return "I declare that God who started this work in me will bring it to completion. What He promised, He will perform. I will not stop believing. My breakthrough is on its way."
        }
    }
}
```

### Speech Transcription

**File:** `Services/PersonalDeclaration/SpeechTranscriptionService.swift`

```swift
import Speech
import AVFoundation

final class SpeechTranscriptionService: SpeechTranscriptionProtocol {
    private var audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let recognizer = SFSpeechRecognizer(locale: .current)
    private var latestTranscription: String = ""

    private(set) var isRecording = false

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startRecording() async throws {
        let node = audioEngine.inputNode
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            self?.latestTranscription = result?.bestTranscription.formattedString ?? ""
        }

        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() async -> String {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        isRecording = false
        return latestTranscription
    }
}
```

### Repository (MVP — UserDefaults)

**File:** `Services/PersonalDeclaration/PersonalDeclarationRepository.swift`

```swift
final class PersonalDeclarationRepository: PersonalDeclarationRepositoryProtocol {
    private let key = "personal_declaration_v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ declaration: PersonalDeclaration) async throws {
        let data = try JSONEncoder().encode(declaration)
        defaults.set(data, forKey: key)
    }

    func load() async -> PersonalDeclaration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersonalDeclaration.self, from: data)
    }

    func markReceived(id: UUID, testimony: String?) async throws {
        guard var declaration = await load(), declaration.id == id else { return }
        declaration.receivedDate = Date()
        declaration.testimony = testimony
        try await save(declaration)
    }

    func clear() async throws {
        defaults.removeObject(forKey: key)
    }
}
```

> **v2 migration note:** When adding testimonies history, create `CoreDataPersonalDeclarationRepository` implementing the same protocol. Change one line in `DIContainer`. On first launch after update, check if UserDefaults key exists → migrate to CoreData → delete UserDefaults key.

### Notification Service

**File:** `Services/PersonalDeclaration/DeclarationNotificationService.swift`

```swift
import UserNotifications

final class DeclarationNotificationService: DeclarationNotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()
    private let notificationId = "personal_declaration_reminder"

    func schedule(for declaration: PersonalDeclaration) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

        let content = UNMutableNotificationContent()
        content.title = "Don't forget what you're believing for 🙏"
        content.body = String(declaration.declarationText.prefix(120)) + "..."
        content.sound = .default
        content.userInfo = ["deepLink": "personalDeclaration"]

        // Fires daily at 8am — independent of the regular declaration reminders
        var components = DateComponents()
        components.hour = 8
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationId,
                                            content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
    }
}
```

---

## Use Cases

**Directory:** `Services/PersonalDeclaration/UseCases/`

```swift
// MatchDeclarationUseCase.swift
final class MatchDeclarationUseCase {
    private let matcher: DeclarationMatcherProtocol

    init(matcher: DeclarationMatcherProtocol) { self.matcher = matcher }

    func execute(input: String) -> DeclarationMatch {
        let sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return matcher.match(input: "faith") }
        return matcher.match(input: sanitized)
    }
}

// SavePersonalDeclarationUseCase.swift
final class SavePersonalDeclarationUseCase {
    private let repository: PersonalDeclarationRepositoryProtocol
    private let notificationService: DeclarationNotificationServiceProtocol

    init(repository: PersonalDeclarationRepositoryProtocol,
         notificationService: DeclarationNotificationServiceProtocol) {
        self.repository = repository
        self.notificationService = notificationService
    }

    func execute(beliefText: String, match: DeclarationMatch) async throws -> PersonalDeclaration {
        let declaration = PersonalDeclaration(
            id: UUID(),
            beliefText: beliefText,
            declarationText: match.declarationText,
            verse: match.verse,
            verseReference: match.verseReference,
            categoryRaw: match.category.rawValue,
            startDate: Date()
        )
        try await repository.save(declaration)
        notificationService.schedule(for: declaration)
        return declaration
    }
}

// MarkDeclarationReceivedUseCase.swift
final class MarkDeclarationReceivedUseCase {
    private let repository: PersonalDeclarationRepositoryProtocol
    private let notificationService: DeclarationNotificationServiceProtocol

    init(repository: PersonalDeclarationRepositoryProtocol,
         notificationService: DeclarationNotificationServiceProtocol) {
        self.repository = repository
        self.notificationService = notificationService
    }

    func execute(id: UUID, testimony: String?) async throws {
        try await repository.markReceived(id: id, testimony: testimony)
        notificationService.cancel()
    }
}
```

---

## ViewModel

**File:** `ViewModels/PersonalDeclarationViewModel.swift`

```swift
enum PersonalDeclarationStep {
    case input      // mic / text entry
    case matching   // 1.5s loading — builds anticipation
    case result     // shows verse + declaration
}

@MainActor
final class PersonalDeclarationViewModel: ObservableObject {

    // MARK: - Published State
    @Published var step: PersonalDeclarationStep = .input
    @Published var inputText: String = ""
    @Published var isRecording: Bool = false
    @Published var showTextInput: Bool = false
    @Published var match: DeclarationMatch? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Injected Dependencies
    private let matchUseCase: MatchDeclarationUseCase
    private let saveUseCase: SavePersonalDeclarationUseCase
    private let speechService: SpeechTranscriptionProtocol

    init(matchUseCase: MatchDeclarationUseCase,
         saveUseCase: SavePersonalDeclarationUseCase,
         speechService: SpeechTranscriptionProtocol) {
        self.matchUseCase = matchUseCase
        self.saveUseCase = saveUseCase
        self.speechService = speechService
    }

    // MARK: - Actions

    func startRecording() async {
        let permitted = await speechService.requestPermission()
        guard permitted else {
            showTextInput = true  // graceful fallback
            return
        }
        do {
            try await speechService.startRecording()
            isRecording = true
        } catch {
            showTextInput = true
        }
    }

    func stopRecording() async {
        let transcribed = await speechService.stopRecording()
        isRecording = false
        inputText = transcribed
        await runMatch(input: transcribed)
    }

    func submitTextInput() async {
        await runMatch(input: inputText)
    }

    func saveAndContinue() async throws -> PersonalDeclaration {
        guard let match else { throw PersonalDeclarationError.noMatch }
        return try await saveUseCase.execute(beliefText: inputText, match: match)
    }

    // MARK: - Private

    private func runMatch(input: String) async {
        step = .matching
        try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5s — intentional pause
        match = matchUseCase.execute(input: input)
        step = .result
    }
}

enum PersonalDeclarationError: Error {
    case noMatch
}
```

---

## Views

### Onboarding Screen

**File:** `Views/Onboarding/PersonalDeclarationOnboardingView.swift`

Three states driven by ViewModel — View has zero logic.

```swift
struct PersonalDeclarationOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: PersonalDeclarationViewModel

    let size: CGSize
    let onComplete: (PersonalDeclaration?) -> Void  // nil = user skipped

    var body: some View {
        ZStack {
            // Background — same as other onboarding screens
            Image("onboarding_bg") // use existing background asset
                .resizable().aspectRatio(contentMode: .fill).ignoresSafeArea()
            Color.black.opacity(0.45).ignoresSafeArea()

            switch viewModel.step {
            case .input:    inputView
            case .matching: matchingView
            case .result:   resultView
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Text("What's one thing you're\ntrusting God for?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Speak it out. This becomes your daily declaration\nuntil it comes to pass.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            if viewModel.showTextInput {
                VStack(spacing: 16) {
                    TextEditor(text: $viewModel.inputText)
                        .frame(height: 100)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.12)))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 24)

                    ShimmerButton(colors: [.blue], buttonTitle: "Find My Declaration") {
                        Task { await viewModel.submitTextInput() }
                    }
                    .frame(width: size.width * 0.87, height: 50)
                }
            } else {
                VStack(spacing: 20) {
                    // Mic button
                    Button {
                        Task {
                            if viewModel.isRecording {
                                await viewModel.stopRecording()
                            } else {
                                await viewModel.startRecording()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(viewModel.isRecording ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                                .scaleEffect(viewModel.isRecording ? 1.15 : 1.0)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                           value: viewModel.isRecording)

                            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }

                    Text(viewModel.isRecording ? "Tap to stop" : "Hold to speak")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))

                    Button("Type instead") {
                        viewModel.showTextInput = true
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                }
            }

            Spacer()

            Button("Skip for now") { onComplete(nil) }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))
                .padding(.bottom, size.height * 0.05)
        }
    }

    // MARK: - Matching View (loading state)

    private var matchingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white).scaleEffect(1.4)
            Text("Finding your declaration...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer().frame(height: 32)

                Text("Here's what God says about that.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))

                if let match = viewModel.match {
                    // Verse block
                    VStack(spacing: 8) {
                        Text(match.verse)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("— \(match.verseReference)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.1)))
                    .padding(.horizontal, 24)

                    // Declaration block
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR DECLARATION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.yellow.opacity(0.8))
                        Text(match.declarationText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                    )
                    .padding(.horizontal, 24)

                    // CTA
                    ShimmerButton(colors: [.blue], buttonTitle: "Speak This Every Day →") {
                        Task {
                            do {
                                let declaration = try await viewModel.saveAndContinue()
                                appState.hasPersonalDeclaration = true
                                onComplete(declaration)
                            } catch {
                                viewModel.errorMessage = "Something went wrong. Please try again."
                            }
                        }
                    }
                    .frame(width: size.width * 0.87, height: 50)
                    .padding(.top, 8)
                }

                Spacer().frame(height: 40)
            }
        }
    }
}
```

### Home Screen Card

**File:** `Views/Declaration View/Components/PersonalDeclarationCard.swift`

```swift
struct PersonalDeclarationCard: View {
    let declaration: PersonalDeclaration
    let onSpeak: () -> Void
    let onMarkReceived: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("YOUR PERSONAL DECLARATION", systemImage: "hands.sparkles.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.yellow)
                Spacer()
                Text("Day \(declaration.dayCount) of believing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
            }

            // Declaration text
            Text(declaration.declarationText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(3)

            // Verse
            Text("📖 \(declaration.verseReference)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))

            // Actions
            HStack(spacing: 10) {
                Button(action: onSpeak) {
                    Label("Speak It", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button(action: onMarkReceived) {
                    Label("It Came to Pass", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}
```

Inject into the home/declarations feed at the top when `appState.hasPersonalDeclaration == true`.

Tapping **Speak It** → `AVSpeechSynthesizer` reads declaration aloud.

### Breakthrough Flow

**File:** `Views/BreakthroughFlowView.swift`

Three-step sheet:

**Step 1 — Confirm**
```
"You're saying God came through?"
[Yes — He did it! 🙌]  [Not yet — keep believing]
```

**Step 2 — Testimony (optional)**
```
"What happened? Share your testimony."
[Text field]
[Save]  [Skip]
```

**Step 3 — Celebration**
```
🎉 Confetti animation

"Your faith moved mountains."
"You believed for [X] days and God was faithful."

[Set a New Declaration →]
[Go to Home]
```

On completion:
- Call `MarkDeclarationReceivedUseCase`
- Set `appState.hasPersonalDeclaration = false`
- Hide card from home screen
- Cancel personal declaration notification
- If "Set New Declaration" → present `PersonalDeclarationOnboardingView` as sheet (resets flow)

---

## Dependency Injection

**File:** `App/DIContainer.swift`

```swift
final class DIContainer {
    static let shared = DIContainer()
    private init() {}

    // Swap concrete types here without touching anything else
    lazy var declarationMatcher: DeclarationMatcherProtocol = KeywordDeclarationMatcher()
    lazy var personalDeclarationRepository: PersonalDeclarationRepositoryProtocol = PersonalDeclarationRepository()
    lazy var declarationNotificationService: DeclarationNotificationServiceProtocol = DeclarationNotificationService()
    lazy var speechService: SpeechTranscriptionProtocol = SpeechTranscriptionService()

    func makePersonalDeclarationViewModel() -> PersonalDeclarationViewModel {
        PersonalDeclarationViewModel(
            matchUseCase: MatchDeclarationUseCase(matcher: declarationMatcher),
            saveUseCase: SavePersonalDeclarationUseCase(
                repository: personalDeclarationRepository,
                notificationService: declarationNotificationService
            ),
            speechService: speechService
        )
    }
}
```

Usage in `OnboardingView`:
```swift
PersonalDeclarationOnboardingView(
    viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
    size: geometry.size
) { declaration in
    if let declaration {
        // Pass to paywall for personalized copy
        // Notification categories already updated inside SaveUseCase
    }
    advance()
}
.tag(Tab.personalDeclaration)
```

---

## Downstream Impact (what else changes)

### Notification Categories
After saving, merge the personal declaration's category into the user's notification categories so their daily declarations reinforce what they're believing for:

```swift
// In SavePersonalDeclarationUseCase.execute() — after saving:
var categories = Set(
    appState.selectedNotificationCategories
        .components(separatedBy: ",")
        .compactMap { DeclarationCategory($0) }
)
categories.insert(declaration.category ?? .faith)
appState.selectedNotificationCategories = categories.map { $0.rawValue }.joined(separator: ",")
```

### Declarations Feed
Weight the personal declaration's category higher in the shuffle so related content appears more frequently. Add extra slots to that category in `NotificationProcessor.getNotificationData()`.

### Streak Reframe (nice to have — v1.5)
If `hasPersonalDeclaration`, change streak label from "Day X" to "Day X of believing." Small copy change, large psychological difference.

### Settings / Profile
Add "My Declaration" row showing:
- Current declaration text (truncated)
- Day count
- Tap → full view with Edit + Mark Received options

---

## Files to Create / Modify

| File | Action |
|---|---|
| `Models/PersonalDeclaration.swift` | **Create** |
| `Services/PersonalDeclaration/Protocols/DeclarationMatcherProtocol.swift` | **Create** |
| `Services/PersonalDeclaration/Protocols/SpeechTranscriptionProtocol.swift` | **Create** |
| `Services/PersonalDeclaration/Protocols/PersonalDeclarationRepositoryProtocol.swift` | **Create** |
| `Services/PersonalDeclaration/Protocols/DeclarationNotificationServiceProtocol.swift` | **Create** |
| `Services/PersonalDeclaration/DeclarationMatcher.swift` | **Create** |
| `Services/PersonalDeclaration/DeclarationContent.swift` | **Create** |
| `Services/PersonalDeclaration/SpeechTranscriptionService.swift` | **Create** |
| `Services/PersonalDeclaration/PersonalDeclarationRepository.swift` | **Create** |
| `Services/PersonalDeclaration/DeclarationNotificationService.swift` | **Create** |
| `Services/PersonalDeclaration/UseCases/MatchDeclarationUseCase.swift` | **Create** |
| `Services/PersonalDeclaration/UseCases/SavePersonalDeclarationUseCase.swift` | **Create** |
| `Services/PersonalDeclaration/UseCases/MarkDeclarationReceivedUseCase.swift` | **Create** |
| `ViewModels/PersonalDeclarationViewModel.swift` | **Create** |
| `App/DIContainer.swift` | **Create** |
| `Views/Onboarding/PersonalDeclarationOnboardingView.swift` | **Create** |
| `Views/Declaration View/Components/PersonalDeclarationCard.swift` | **Create** |
| `Views/BreakthroughFlowView.swift` | **Create** |
| `Views/Onboarding/OnboardingView.swift` | **Modify** — add tab, update advance(), pass declaration to paywall |
| `Views/Onboarding/Model/OnboardingTypes.swift` | **Modify** — add `case personalDeclaration` |
| `App/AppState.swift` | **Modify** — add `hasPersonalDeclaration: Bool` |
| `Views/Declaration View/` (home feed) | **Modify** — inject `PersonalDeclarationCard` at top |

**`Info.plist` — add permission keys:**
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>SpeakLife uses speech recognition to transcribe your personal declaration.</string>
<key>NSMicrophoneUsageDescription</key>
<string>SpeakLife uses your microphone to record your personal declaration.</string>
```

---

## Edge Cases

| Scenario | Behavior |
|---|---|
| User skips the screen | `hasPersonalDeclaration` stays false, no card, no extra notification |
| Speech permission denied | Auto-falls back to text input |
| Input unrecognizable / too short | Defaults to `.faith` category |
| User marks received → sets new one | Old entry archived in memory (testimony stored), new declaration replaces it |
| App reinstalled | UserDefaults cleared → treated as new user, no declaration |

---

## Gap Closures — Required Before Ship

These four gaps must be closed for the feature loop to be complete.

---

### Gap 1 — Notification Deep Link Handling

**Problem:** The notification fires with `userInfo["deepLink"] = "personalDeclaration"` but `SpeakLifeApp.handleNotificationContent()` has no handler for it. Tapping the notification opens the app but nothing navigates to the card.

**File:** `App/SpeakLifeApp.swift` — `handleNotificationContent()`

```swift
private func handleNotificationContent(_ content: UNNotificationContent) {

    let notifType = content.userInfo["notificationType"] as? String
    if notifType == "prayerWall" || notifType == "streakAtRisk" || notifType == "streakComplete" {
        return
    }

    if let deepLink = content.userInfo["deepLink"] as? String {
        switch deepLink {
        case "declarations":
            tabViewModel.selectedTab = 0
            return

        case "personalDeclaration":          // ← ADD THIS
            tabViewModel.selectedTab = 0     // home tab
            appState.scrollToPersonalDeclaration = true  // home screen observes this flag
            return

        default:
            break
        }
    }

    // ... rest of existing handling unchanged
}
```

**`AppState.swift` — add:**
```swift
@AppStorage("scrollToPersonalDeclaration") var scrollToPersonalDeclaration: Bool = false
```

**Home screen** — observe this flag. When true, scroll to and briefly highlight the `PersonalDeclarationCard`, then reset to false.

---

### Gap 2 — Notification Time Uses User's Setting

**Problem:** `DeclarationNotificationService` hardcodes 8am. The user just chose their notification time. These must match.

**Update protocol:**
```swift
protocol DeclarationNotificationServiceProtocol {
    func schedule(for declaration: PersonalDeclaration, startTimeIndex: Int)
    func cancel()
}
```

**Update `DeclarationNotificationService.schedule(for:startTimeIndex:)`:**
```swift
func schedule(for declaration: PersonalDeclaration, startTimeIndex: Int) {
    center.removePendingNotificationRequests(withIdentifiers: [notificationId])

    let content = UNMutableNotificationContent()
    content.title = "Don't forget what you're believing for 🙏"
    content.body = String(declaration.declarationText.prefix(120)) + "..."
    content.sound = .default
    content.userInfo = ["deepLink": "personalDeclaration"]

    // startTimeIndex = 30-min slots from midnight
    // e.g. index 12 = 6:00 AM, index 16 = 8:00 AM, index 24 = 12:00 PM
    let totalMinutes = startTimeIndex * 30
    var components = DateComponents()
    components.hour = (totalMinutes / 60) % 24
    components.minute = totalMinutes % 60

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    center.add(UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger),
               withCompletionHandler: nil)
}
```

**Update `SavePersonalDeclarationUseCase.execute()`** to accept `startTimeIndex: Int` and pass it to `notificationService.schedule(for:startTimeIndex:)`.

**Update `PersonalDeclarationViewModel.saveAndContinue()`** to accept and forward `startTimeIndex: Int`.

**Update call site in result view:**
```swift
ShimmerButton(colors: [.blue], buttonTitle: "Speak This Every Day →") {
    Task {
        do {
            let declaration = try await viewModel.saveAndContinue(startTimeIndex: appState.startTimeIndex)
            appState.hasPersonalDeclaration = true
            onComplete(declaration)
        } catch {
            viewModel.errorMessage = "Something went wrong. Please try again."
        }
    }
}
```

---

### Gap 3 — "Speak It" TTS Owner

**Problem:** `PersonalDeclarationCard` has an `onSpeak` callback but nothing owns the speech synthesizer.

**Solution:** The app already has `SpeechSynthesizer.swift` at `Core/Components/SpeechSynthesizer.swift` with `speakText(_ text: String)`. No new service needed.

In the **parent view that renders `PersonalDeclarationCard`** (the declarations home feed):

```swift
@StateObject private var speechSynthesizer = SpeechSynthesizer()

PersonalDeclarationCard(
    declaration: declaration,
    onSpeak: {
        speechSynthesizer.speakText(declaration.declarationText)
    },
    onMarkReceived: {
        showBreakthroughFlow = true
    }
)
```

No new files. No new protocols. Reuse what already exists.

---

### Gap 4 — Paywall Integration

**Problem:** Both paywall views (`HighConversionPaywallView` and `OptimizedSubscriptionView`) read copy from `UserPreferencesTracker.getDynamicPaywallCopy()`. The personal declaration belief isn't wired in, so the conversion uplift is lost.

**Cleanest path:** Set a transient value on `UserPreferencesTracker` before advancing — no view signature changes required.

**Step 1 — Add to `UserPreferencesTracker`:**
```swift
// In-memory only — only needed during onboarding session
var personalDeclarationBelief: String? = nil
```

**Step 2 — Add override at top of `getDynamicPaywallCopy()`:**
```swift
func getDynamicPaywallCopy() -> PaywallCopy {
    if let belief = personalDeclarationBelief, !belief.isEmpty {
        return PaywallCopy(
            headline: "You just declared what you're trusting God for.",
            subheadline: "SpeakLife will send you this declaration every single day until it comes to pass. Don't miss a day.",
            urgencyText: "3 Days Free • Cancel Anytime"
        )
    }
    // ... existing survey-based logic unchanged below
}
```

**Step 3 — Set it in `OnboardingView` after save:**
```swift
PersonalDeclarationOnboardingView(
    viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
    size: geometry.size
) { declaration in
    if let declaration {
        appState.hasPersonalDeclaration = true
        UserPreferencesTracker.shared.personalDeclarationBelief = declaration.beliefText
    }
    advance()  // → .subscription (paywall now reads personalized copy)
}
.tag(Tab.personalDeclaration)
```

---

## Complete Feature Loop (all gaps closed)

```
[Onboarding]
User speaks/types → matched verse + declaration shown
       ↓
Saves → notification scheduled at user's chosen time ✓ Gap 2
Advances → paywall shows personalized copy ✓ Gap 4
       ↓
[Daily habit]
Notification fires at user's time → user taps
       ↓
Deep links to home → scrolls to card ✓ Gap 1
       ↓
Taps "Speak It" → SpeechSynthesizer.speakText() ✓ Gap 3
       ↓
[Breakthrough]
Taps "It Came to Pass" → testimony → celebration
       ↓
"Set a New Declaration" → loop restarts as sheet
```

---

## Out of Scope — v1

- AI-powered matching (keyword matching ships first)
- CloudKit / cross-device sync (UserDefaults is sufficient for MVP)
- Social testimony sharing
- Multiple simultaneous declarations
- Analytics events (add after validating feature retention impact)

---

## Testing

All business logic is in Use Cases and ViewModel — fully testable with mock implementations of protocols. No real speech, storage, or notifications required in tests.

```swift
// Example
func test_anxiety_keywords_match_correctly() {
    let matcher = KeywordDeclarationMatcher()
    let result = MatchDeclarationUseCase(matcher: matcher).execute(input: "I struggle with anxiety every night")
    XCTAssertEqual(result.category, .anxiety)
}

func test_save_schedules_notification() async throws {
    let mockRepo = MockPersonalDeclarationRepository()
    let mockNotif = MockDeclarationNotificationService()
    let useCase = SavePersonalDeclarationUseCase(repository: mockRepo, notificationService: mockNotif)
    let match = DeclarationMatch(category: .faith, declarationText: "test", verse: "test", verseReference: "test")
    _ = try await useCase.execute(beliefText: "healing", match: match)
    XCTAssertTrue(mockNotif.scheduleCalled)
    XCTAssertTrue(mockRepo.saveCalled)
}
```
