//
//  DeclarationVerificationService.swift
//  SpeakLife
//
//  Real-time speech verification for personal declarations.
//  Listens as user speaks, matches words against the declaration text,
//  and publishes live match state for karaoke-style highlighting.
//

import Foundation
import Speech
import AVFoundation
import Combine

enum DeclarationVerificationError: Error {
    case microphonePermissionDenied
    case speechPermissionDenied
    case engineFailure
}

@MainActor
final class DeclarationVerificationService: ObservableObject {

    // MARK: - Published state (drives UI)

    @Published var matchedIndices: Set<Int> = []
    @Published var matchPercentage: Double = 0
    @Published var isRecording = false

    // MARK: - Private

    private(set) var declarationWords: [String] = []
    private var audioEngine: AVAudioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)

    // MARK: - Setup

    func prepare(declarationText: String) {
        declarationWords = Self.tokenize(declarationText)
        matchedIndices = []
        matchPercentage = 0
    }

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        // 1. Speech recognition
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        // 2. Microphone
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return micGranted
    }

    // MARK: - Recording

    func startRecording() async throws {
        // Check permissions FIRST — before touching AVAudioEngine
        let speechOK = SFSpeechRecognizer.authorizationStatus() == .authorized
        let micOK = AVAudioApplication.recordPermission == .granted

        if !speechOK {
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            guard granted else { throw DeclarationVerificationError.speechPermissionDenied }
        }

        if !micOK {
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { g in
                    continuation.resume(returning: g)
                }
            }
            guard granted else { throw DeclarationVerificationError.microphonePermissionDenied }
        }

        teardown()
        // Fresh engine every session — reusing a stopped engine is unreliable
        audioEngine = AVAudioEngine()
        matchedIndices = []
        matchPercentage = 0

        // Set up audio session BEFORE accessing inputNode
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let node = audioEngine.inputNode

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let capturedWords = declarationWords

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                let (pct, indices) = Self.computeMatch(transcription: transcription,
                                                       declarationWords: capturedWords)
                Task { @MainActor [weak self] in
                    self?.matchedIndices = indices
                    self?.matchPercentage = pct
                }
            }
            if error != nil { Task { @MainActor [weak self] in self?.teardown() } }
        }

        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() -> Double {
        let result = matchPercentage
        teardown()
        return result
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

    // MARK: - Teardown

    private func teardown() {
        if audioEngine.isRunning { audioEngine.stop() }
        try? { audioEngine.inputNode.removeTap(onBus: 0) }()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false,
            options: .notifyOthersOnDeactivation)
    }
}
