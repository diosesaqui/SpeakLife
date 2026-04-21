//
//  DeclarationVerificationService.swift
//  SpeakLife
//
//  Verifies that the user spoke their declaration.
//  Records via AVAudioRecorder (no installTap — avoids AVFAudio NSException crash),
//  then transcribes the file with SFSpeechRecognizer after recording stops.
//

import Foundation
import Speech
import AVFoundation
import Combine

enum DeclarationVerificationError: Error {
    case microphonePermissionDenied
    case speechPermissionDenied
}

@MainActor
final class DeclarationVerificationService: ObservableObject {

    // MARK: - Published state

    @Published var matchedIndices: Set<Int> = []
    @Published var matchPercentage: Double = 0
    @Published var isRecording = false
    @Published var isTranscribing = false

    // MARK: - Private

    private(set) var declarationWords: [String] = []
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("declaration_verify.m4a")
    }
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)

    // MARK: - Setup

    func prepare(declarationText: String) {
        declarationWords = Self.tokenize(declarationText)
        matchedIndices = []
        matchPercentage = 0
    }

    // MARK: - Permissions

    private func checkAndRequestPermissions() async throws {
        // Speech recognition
        if SFSpeechRecognizer.authorizationStatus() != .authorized {
            let status = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
            }
            guard status == .authorized else {
                throw DeclarationVerificationError.speechPermissionDenied
            }
        }

        // Microphone
        if AVAudioSession.sharedInstance().recordPermission != .granted {
            let granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
            guard granted else {
                throw DeclarationVerificationError.microphonePermissionDenied
            }
        }
    }

    // MARK: - Recording (AVAudioRecorder — no installTap)

    func startRecording() async throws {
        try await checkAndRequestPermissions()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

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

        let rec = try AVAudioRecorder(url: recordingURL, settings: settings)
        rec.record()
        recorder = rec
        matchedIndices = []
        matchPercentage = 0
        isRecording = true
    }

    /// Stops recording, transcribes the audio, and returns the match percentage.
    func stopAndTranscribe() async -> Double {
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false,
            options: .notifyOthersOnDeactivation)

        isTranscribing = true
        defer { isTranscribing = false }

        let pct = await transcribeRecording()
        matchPercentage = pct
        return pct
    }

    // MARK: - Transcription

    private func transcribeRecording() async -> Double {
        guard FileManager.default.fileExists(atPath: recordingURL.path) else { return 0 }
        guard let recognizer = recognizer, recognizer.isAvailable else { return 0 }

        let request = SFSpeechURLRecognitionRequest(url: recordingURL)
        request.shouldReportPartialResults = false

        let capturedWords = declarationWords

        return await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let final = result, final.isFinal else {
                    if error != nil { continuation.resume(returning: 0) }
                    return
                }
                let transcription = final.bestTranscription.formattedString
                let (pct, indices) = Self.computeMatch(transcription: transcription,
                                                       declarationWords: capturedWords)
                Task { @MainActor [weak self] in
                    self?.matchedIndices = indices
                }
                continuation.resume(returning: pct)
            }
        }
    }

    // MARK: - Word Matching

    private static func computeMatch(transcription: String,
                                     declarationWords: [String]) -> (Double, Set<Int>) {
        guard !declarationWords.isEmpty else { return (0, []) }
        let spoken = Set(tokenize(transcription))
        var matched = Set<Int>()
        for (i, word) in declarationWords.enumerated() {
            if spoken.contains(word) { matched.insert(i) }
        }
        let pct = Double(matched.count) / Double(declarationWords.count)
        return (pct, matched)
    }

    // MARK: - Text Normalisation

    static func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .map { normalize($0) }
            .filter { !$0.isEmpty }
    }

    static func normalize(_ word: String) -> String {
        var w = word.lowercased()
        let contractions: [String: String] = [
            "i'm": "im", "i've": "ive", "i'll": "ill", "i'd": "id",
            "god's": "gods", "he's": "hes", "she's": "shes", "it's": "its",
            "that's": "thats", "there's": "theres", "don't": "dont",
            "can't": "cant", "won't": "wont", "isn't": "isnt",
            "aren't": "arent", "wasn't": "wasnt", "didn't": "didnt"
        ]
        for (k, v) in contractions { w = w.replacingOccurrences(of: k, with: v) }
        return w.filter { $0.isLetter }
    }
}
