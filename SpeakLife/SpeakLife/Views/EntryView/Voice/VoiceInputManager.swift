//
//  VoiceInputManager.swift
//  SpeakLife
//
//  Voice input and speech-to-text for journal and affirmation entries.
//
//  Uses AVAudioRecorder + SFSpeechURLRecognitionRequest.
//  AVAudioEngine/installTap was removed — it raises an uncatchable NSException
//  (AUGraphNodeBaseV3::CreateRecordingTap) on certain devices/OS versions.
//

import Foundation
import Speech
import AVFoundation
import SwiftUI

enum VoiceInputState: CaseIterable {
    case idle           // Mic button ready
    case listening      // Actively recording
    case processing     // Transcribing audio
    case transcribing   // Text updating (alias for processing — kept for UI compat)
    case paused         // Not used in recorder model, kept for compat
    case completed      // Transcription done
    case error          // Error occurred
}

@MainActor
class VoiceInputManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var transcribedText: String = ""
    @Published var isListening: Bool = false
    @Published var voiceInputState: VoiceInputState = .idle
    @Published var audioLevels: [Float] = []
    @Published var hasPermissions: Bool = false
    @Published var errorMessage: String?
    @Published var transcriptionConfidence: Float = 0.0
    @Published var alternativeTranscriptions: [String] = []

    // MARK: - Private

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var audioLevelTimer: Timer?
    private var maxDurationTimer: Timer?
    private var sessionObservers: [NSObjectProtocol] = []

    // 60s keeps the uncompressed PCM file small (~5-6 MB) and stays within the
    // practical duration limit of server-based recognition, which can fail or
    // return empty on longer single requests. Users can tap the mic again to
    // dictate more; each result is appended.
    private let maxRecordingDuration: TimeInterval = 60

    override init() {
        super.init()
        checkInitialPermissions()
        registerSessionObservers()
    }

    deinit {
        sessionObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Permissions

    private func checkInitialPermissions() {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioSession.sharedInstance().recordPermission
        hasPermissions = speech == .authorized && mic == .granted
    }

    func requestPermissions() async -> Bool {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        hasPermissions = speechGranted && micGranted
        return hasPermissions
    }

    // MARK: - Recording Control

    func startListening() {
        guard hasPermissions else {
            errorMessage = "Microphone and speech recognition permissions are required"
            voiceInputState = .error
            return
        }
        guard !isListening else { return }

        // Start downloading the iOS 26 on-device model (if needed) now, so it's
        // likely ready by the time the user stops speaking.
        if #available(iOS 26.0, *) {
            prewarmSpeechModel()
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")

            // Use the session's actual sample rate — never hardcode 44100.
            // On iOS 26+ the hardware may negotiate a different rate and
            // AVAudioRecorder will crash during format init if they don't match.
            let sampleRate = session.sampleRate > 0 ? session.sampleRate : 44100.0
            // Record lossless 16-bit linear PCM rather than compressed AAC. AAC
            // discards high-frequency detail that the recognizer relies on for
            // consonants, so feeding it uncompressed audio measurably improves
            // transcription accuracy. The recognizer downsamples internally, so
            // recording at the hardware rate is fine.
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            recordingURL = url

            isListening = true
            voiceInputState = .listening
            errorMessage = nil

            startAudioLevelMonitoring()

            maxDurationTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in self?.stopListening() }
            }

            Juice.play(.tapSolid)

        } catch {
            // setActive(true) may have already activated the session before the
            // recorder threw; tear it down so we don't leave other audio ducked
            // and the recording indicator stuck on.
            cleanup()
            voiceInputState = .error
            errorMessage = "Could not start recording. Please try again."
        }
    }

    func stopListening() {
        guard isListening else { return }

        isListening = false
        stopAudioLevelMonitoring()
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil

        audioRecorder?.stop()
        Juice.play(.tapLight)

        guard let url = recordingURL else {
            cleanup()
            voiceInputState = .idle
            return
        }

        // On iOS 26+ transcription runs fully on-device via SpeechAnalyzer, so a
        // missing network / unavailable legacy recognizer must NOT block it.
        // Only gate on the legacy recognizer for the SFSpeechRecognizer path.
        if #available(iOS 26.0, *) {
            // SpeechAnalyzer handles availability itself; proceed.
        } else {
            guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                cleanup()
                errorMessage = "Speech recognition is unavailable right now. Check your connection and try again."
                voiceInputState = .error
                return
            }
        }

        voiceInputState = .processing

        Task {
            let result = await transcribe(url: url)
            cleanup()

            transcribedText = result.text
            transcriptionConfidence = result.confidence
            alternativeTranscriptions = result.alternatives
            if transcribedText.isEmpty {
                // Don't strand the user on a silent "Transcribing…" dead-end.
                errorMessage = "Didn't catch that. Please try speaking again."
                voiceInputState = .error
            } else {
                errorMessage = nil
                voiceInputState = .completed
            }
        }
    }

    func pauseListening() {
        // Not meaningful in recorder model — map to stop
        stopListening()
    }

    func resumeListening() {
        // Not meaningful in recorder model
    }

    // MARK: - Session Interruptions

    private func registerSessionObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        sessionObservers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor in self?.handleInterruption() }
        })

        // Headset/AirPods removed mid-recording deactivates the input route.
        sessionObservers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.handleInterruption() }
        })
    }

    private func handleInterruption() {
        // A phone call, Siri, or an unplugged headset deactivated our session
        // mid-record. Stop cleanly so we transcribe what was captured instead of
        // freezing on "Listening…" until the max-duration timer fires.
        guard isListening else { return }
        stopListening()
    }

    func clearTranscription() {
        transcribedText = ""
        voiceInputState = .idle
        errorMessage = nil
        audioLevels.removeAll()
    }

    func finalizePendingTranscription() {
        if !transcribedText.isEmpty {
            transcribedText = enhanceTranscription(transcribedText)
            voiceInputState = .completed
        }
    }

    // MARK: - Transcription

    private struct TranscriptionResult {
        let text: String
        let confidence: Float
        let alternatives: [String]
    }

    private func transcribe(url: URL) async -> TranscriptionResult {
        // Prefer Apple's iOS 26 on-device model (SpeechAnalyzer) — it's markedly
        // more accurate than the legacy recognizer. Fall back to
        // SFSpeechRecognizer on older OSes, or when the iOS 26 model isn't
        // installed yet or fails for this clip.
        if #available(iOS 26.0, *) {
            if let modern = await transcribeWithSpeechAnalyzer(url: url) {
                return modern
            }
        }
        return await transcribeLegacy(url: url)
    }

    private func transcribeLegacy(url: URL) async -> TranscriptionResult {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            return TranscriptionResult(text: "", confidence: 0, alternatives: [])
        }

        return await withCheckedContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.contextualStrings = getExtendedContextualStrings()

            if #available(iOS 16.0, *) {
                request.addsPunctuation = true
                request.taskHint = .dictation
            }

            // The recognition handler runs on Speech's own queue and can fire
            // more than once. Guard the single resume with a lock: an
            // unsynchronized flag lets two callbacks both pass the check and
            // resume the continuation twice, which is a fatal crash
            // ("SWIFT TASK CONTINUATION MISUSE"). The lock also lets a timeout
            // resume exactly once if the task never reports final/error.
            let lock = NSLock()
            var didResume = false
            var task: SFSpeechRecognitionTask?

            func finish(_ result: TranscriptionResult) {
                lock.lock()
                if didResume { lock.unlock(); return }
                didResume = true
                lock.unlock()
                task?.cancel()
                continuation.resume(returning: result)
            }

            task = recognizer.recognitionTask(with: request) { result, error in
                if let result = result, result.isFinal {
                    let best = result.bestTranscription
                    var totalConf: Float = 0
                    for seg in best.segments { totalConf += seg.confidence }
                    let avgConf = best.segments.isEmpty ? 0 : totalConf / Float(best.segments.count)

                    let alts = result.transcriptions
                        .prefix(3)
                        .map { $0.formattedString }
                        .filter { $0 != best.formattedString }

                    finish(TranscriptionResult(
                        text: self.enhanceTranscription(best.formattedString),
                        confidence: avgConf,
                        alternatives: Array(alts)
                    ))
                } else if error != nil {
                    // Recognition failed — return empty rather than hang.
                    finish(TranscriptionResult(text: "", confidence: 0, alternatives: []))
                }
                // Non-final partial with no error — wait for final result.
            }

            // Safety net: if the task delivers neither a final result nor an
            // error (recognizer stalls or goes unavailable mid-task), resume
            // empty so the awaiting Task can't hang on .processing forever.
            DispatchQueue.global().asyncAfter(deadline: .now() + 20) {
                finish(TranscriptionResult(text: "", confidence: 0, alternatives: []))
            }
        }
    }

    // MARK: - SpeechAnalyzer (iOS 26+)

    /// Transcribe the recorded file with Apple's modern on-device model.
    /// Returns nil (so the caller falls back to SFSpeechRecognizer) when the
    /// language model isn't installed yet, the locale is unsupported, or
    /// anything throws. SpeechAnalyzer has no custom-vocabulary API, so the
    /// same `enhanceTranscription` post-processing is applied for proper nouns.
    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzer(url: URL) async -> TranscriptionResult? {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else {
            return nil
        }

        // If the on-device model for this locale isn't ready, kick off a
        // background download and let this clip fall back to the legacy path so
        // the user isn't blocked on a large first-run download.
        let installed = await SpeechTranscriber.installedLocales
        guard installed.contains(where: { $0.identifier == locale.identifier }) else {
            installSpeechModel(for: locale)
            return nil
        }

        do {
            let transcriber = SpeechTranscriber(locale: locale, preset: .offlineTranscription)
            let audioFile = try AVAudioFile(forReading: url)

            // Collect finalized results as the analyzer processes the file.
            async let collected = transcriber.results.reduce(into: AttributedString()) { acc, result in
                acc += result.text
            }

            let analyzer = SpeechAnalyzer(modules: [transcriber])
            guard let lastSample = try await analyzer.analyzeSequence(from: audioFile) else {
                return nil // empty/unreadable audio → let caller decide
            }
            try await analyzer.finalizeAndFinish(through: lastSample)

            let text = String((try await collected).characters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return TranscriptionResult(
                text: enhanceTranscription(text),
                confidence: 1,
                alternatives: []
            )
        } catch {
            return nil
        }
    }

    /// Idempotent background install of the SpeechAnalyzer language model.
    @available(iOS 26.0, *)
    private func installSpeechModel(for locale: Locale) {
        Task.detached {
            let transcriber = SpeechTranscriber(locale: locale, preset: .offlineTranscription)
            if let request = try? await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try? await request.downloadAndInstall()
            }
        }
    }

    /// Warm the on-device model when recording starts so it's likely ready by
    /// the time the user stops speaking.
    @available(iOS 26.0, *)
    private func prewarmSpeechModel() {
        Task {
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else { return }
            let installed = await SpeechTranscriber.installedLocales
            if !installed.contains(where: { $0.identifier == locale.identifier }) {
                installSpeechModel(for: locale)
            }
        }
    }

    // MARK: - Audio Levels

    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateAudioLevels() }
        }
    }

    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }

    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        // Convert dB (-160…0) to 0…1
        let normalized = max(0, min(1, (power + 80) / 80))
        audioLevels.append(normalized)
        if audioLevels.count > 50 { audioLevels.removeFirst() }
    }

    // MARK: - Cleanup

    private func cleanup() {
        audioRecorder = nil
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Text Enhancement

    private func enhanceTranscription(_ text: String) -> String {
        var enhanced = text
        let spiritualTerms = [
            "god", "jesus", "christ", "lord", "father", "holy spirit",
            "bible", "scripture", "prayer", "amen", "hallelujah",
            "blessing", "faith", "grace", "mercy", "salvation", "heaven",
            "gospel", "psalm", "proverbs", "corinthians", "genesis",
            "exodus", "revelation", "matthew", "john", "romans"
        ]
        for term in spiritualTerms {
            let replacement = term.components(separatedBy: " ").map { $0.capitalized }.joined(separator: " ")
            enhanced = enhanced.replacingOccurrences(
                of: "\\b\(term)\\b", with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return enhanced
    }

    private func getContextualStrings() -> [String] {
        ["In Jesus name", "Amen", "Hallelujah", "Praise God", "Thank you Lord",
         "Holy Spirit", "God is good", "By His stripes", "Blood of Jesus",
         "I declare", "I believe", "I receive", "I am blessed",
         "Kingdom of God", "Glory to God", "Faith over fear"]
    }

    private func getExtendedContextualStrings() -> [String] {
        getContextualStrings() + [
            "I speak life", "Prophetic word", "Divine purpose",
            "Godly wisdom", "Heavenly Father", "Christ Jesus",
            "Born again", "Saved by grace", "Walking in faith",
            "Armor of God", "Fruit of the Spirit", "Worship and praise"
        ] + biblicalProperNouns
    }

    /// Proper nouns the recognizer routinely mis-hears (book names, divine
    /// names, key figures). Biasing toward them via contextualStrings is the
    /// single cheapest accuracy win for this domain. Kept well under Apple's
    /// recommended ~100-phrase ceiling so it doesn't dilute the bias.
    private let biblicalProperNouns: [String] = [
        // Divine names
        "Yahweh", "Jehovah", "Elohim", "Adonai", "Abba Father",
        "El Shaddai", "Emmanuel", "Messiah", "Yeshua",
        // Frequently-misheard book names
        "Genesis", "Deuteronomy", "Joshua", "Nehemiah", "Psalms",
        "Proverbs", "Ecclesiastes", "Isaiah", "Jeremiah", "Ezekiel",
        "Habakkuk", "Zephaniah", "Zechariah", "Malachi", "Philippians",
        "Colossians", "Thessalonians", "Philemon", "Hebrews", "Revelation",
        // Key figures and places
        "Abraham", "Moses", "Elijah", "Elisha", "Gideon",
        "Apostle Paul", "Apostle Peter", "Mary Magdalene", "Nazareth", "Galilee"
    ]
}

// MARK: - Convenience

extension VoiceInputManager {
    var canStartListening: Bool {
        hasPermissions && !isListening && voiceInputState != .processing
    }

    var isActivelyRecording: Bool {
        voiceInputState == .listening || voiceInputState == .transcribing
    }

    var hasContent: Bool {
        !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Errors

enum VoiceInputError: LocalizedError {
    case recognitionRequestFailed
    case audioEngineStartFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .recognitionRequestFailed: return "Failed to create speech recognition request"
        case .audioEngineStartFailed: return "Failed to start audio engine"
        case .permissionDenied: return "Microphone or speech recognition permission denied"
        }
    }
}
