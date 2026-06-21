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

    private let maxRecordingDuration: TimeInterval = 300 // 5 min

    override init() {
        super.init()
        checkInitialPermissions()
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

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")

            // Use the session's actual sample rate — never hardcode 44100.
            // On iOS 26+ the hardware may negotiate a different rate and
            // AVAudioRecorder will crash during format init if they don't match.
            let sampleRate = session.sampleRate > 0 ? session.sampleRate : 44100.0
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
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
            voiceInputState = .idle
            return
        }

        voiceInputState = .processing

        Task {
            let result = await transcribe(url: url)
            cleanup()

            transcribedText = result.text
            transcriptionConfidence = result.confidence
            alternativeTranscriptions = result.alternatives
            voiceInputState = transcribedText.isEmpty ? .idle : .completed
        }
    }

    func pauseListening() {
        // Not meaningful in recorder model — map to stop
        stopListening()
    }

    func resumeListening() {
        // Not meaningful in recorder model
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

            // resumed guards against double-resume (crash) and never-resume (hang).
            // SFSpeechRecognitionTask can fire multiple partial callbacks even when
            // shouldReportPartialResults = false on some OS versions.
            var resumed = false

            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }

                if let result = result, result.isFinal {
                    resumed = true

                    let best = result.bestTranscription
                    var totalConf: Float = 0
                    for seg in best.segments { totalConf += seg.confidence }
                    let avgConf = best.segments.isEmpty ? 0 : totalConf / Float(best.segments.count)

                    let alts = result.transcriptions
                        .prefix(3)
                        .map { $0.formattedString }
                        .filter { $0 != best.formattedString }

                    continuation.resume(returning: TranscriptionResult(
                        text: self.enhanceTranscription(best.formattedString),
                        confidence: avgConf,
                        alternatives: Array(alts)
                    ))
                } else if error != nil {
                    // Recognition failed — return empty rather than hang.
                    resumed = true
                    continuation.resume(returning: TranscriptionResult(text: "", confidence: 0, alternatives: []))
                }
                // Non-final partial with no error — wait for final result.
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
        ]
    }
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
