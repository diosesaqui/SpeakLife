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

    // MARK: Endpointing (opt-in — see `startRecording(autoStopAfterSilence:)`)
    //
    // Everything below is additive and inert unless a caller opts in, so the
    // personal-declaration flow behaves exactly as it always has.

    /// Rolling mic amplitude, 0...1, newest last. Drives a live waveform.
    @Published private(set) var levels: [Float] = []
    /// Stamped when auto-stop decided the speaker has finished. The caller
    /// reacts by awaiting `stopAndTranscribe()` — the transcription trigger
    /// stays in one place rather than being duplicated in here.
    @Published private(set) var endpointedAt: Date?
    /// True once speech has been detected at all this run. Lets a caller tell
    /// "hasn't started" apart from "has finished".
    @Published private(set) var hasHeardSpeech = false

    // MARK: - Private

    private(set) var declarationWords: [String] = []
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var maxDurationTimer: Timer?
    private var autoStopSilence: TimeInterval?
    private var preferOnDeviceRecognition = false
    private var silenceSince: Date?
    private var ambientSamples: [Float] = []
    private var listeningSince: Date?
    private var resolvedThreshold: Float?

    /// Endpointing tunables. These only decide WHEN to stop listening — whether
    /// the declaration was actually spoken is settled by the transcript, not by
    /// any of these.
    private let meterInterval: TimeInterval = 0.05
    private let ambientWindow: TimeInterval = 1.0
    private let minimumSpeechThreshold: Float = 0.22
    private let speechMarginOverAmbient: Float = 0.16
    private let maxRecordingSeconds: TimeInterval = 30

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

    /// - Parameter autoStopAfterSilence: when non-nil, the service meters the
    ///   mic and stops itself once the speaker has started and then gone quiet
    ///   for this long, stamping `endpointedAt`. Nil keeps the tap-to-stop
    ///   behaviour the personal-declaration card relies on, unchanged.
    /// - Parameter preferOnDevice: transcribe on device when the phone supports
    ///   it. Defaults to off so the personal-declaration flow keeps the exact
    ///   recognition path it was tuned against.
    func startRecording(autoStopAfterSilence: TimeInterval? = nil,
                        preferOnDevice: Bool = false) async throws {
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
        // Harmless for the tap-to-stop caller; required for endpointing.
        rec.isMeteringEnabled = true
        rec.record()
        recorder = rec
        matchedIndices = []
        matchPercentage = 0
        isRecording = true

        autoStopSilence = autoStopAfterSilence
        preferOnDeviceRecognition = preferOnDevice
        levels = []
        endpointedAt = nil
        hasHeardSpeech = false
        silenceSince = nil
        ambientSamples = []
        resolvedThreshold = nil
        listeningSince = Date()

        guard autoStopAfterSilence != nil else { return }
        meterTimer = Timer.scheduledTimer(withTimeInterval: meterInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sampleLevel() }
        }
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.endpoint() }
        }
    }

    // MARK: - Endpointing

    /// Amplitude is used for ONE thing here: deciding when the speaker has
    /// finished so the recording can be closed and transcribed. It never
    /// decides whether the declaration was spoken — the transcript does that.
    private func sampleLevel() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        var normalized: Float = (power + 50) / 50
        if normalized < 0 { normalized = 0 }
        if normalized > 1 { normalized = 1 }
        levels.append(normalized)
        if levels.count > 48 { levels.removeFirst() }

        // Learn the room first, so a noisy kitchen doesn't read as speech and a
        // quiet room doesn't set the bar below its own hiss.
        if let listeningSince, Date().timeIntervalSince(listeningSince) < ambientWindow {
            ambientSamples.append(normalized)
            return
        }

        if normalized >= resolveThreshold() {
            hasHeardSpeech = true
            silenceSince = nil
            return
        }

        // Only start the clock once they have actually begun — otherwise the
        // pause before someone draws breath ends the recording.
        guard hasHeardSpeech, let autoStopSilence else { return }
        let since = silenceSince ?? Date()
        silenceSince = since
        if Date().timeIntervalSince(since) >= autoStopSilence { endpoint() }
    }

    /// Median, not mean, so one slammed door during the ambient window cannot
    /// push the bar out of reach for the rest of the recording.
    private func resolveThreshold() -> Float {
        if let resolvedThreshold { return resolvedThreshold }
        var threshold: Float = minimumSpeechThreshold
        if !ambientSamples.isEmpty {
            let sorted: [Float] = ambientSamples.sorted()
            let median: Float = sorted[sorted.count / 2]
            let adaptive: Float = median + speechMarginOverAmbient
            if adaptive > threshold { threshold = adaptive }
        }
        if threshold > 0.6 { threshold = 0.6 }
        resolvedThreshold = threshold
        return threshold
    }

    /// "I've said it." Ends the recording on demand.
    ///
    /// Auto-endpointing is the happy path, but it cannot be the only one. It
    /// fires from trailing silence AFTER speech was detected, or from the
    /// 30-second backstop — so a user who re-armed the mic and then didn't
    /// speak again (a failed first pass, a noisy room where the floor never
    /// clears, a phone that missed them) sat there with no way to finish and
    /// nothing telling them how long they'd wait. Someone who has just spoken
    /// a declaration over their own life should never be stuck on the screen
    /// that asked them to.
    func finishSpeaking() {
        endpoint()
    }

    private func endpoint() {
        guard isRecording, endpointedAt == nil else { return }
        stopMetering()
        endpointedAt = Date()
    }

    private func stopMetering() {
        meterTimer?.invalidate(); meterTimer = nil
        maxDurationTimer?.invalidate(); maxDurationTimer = nil
    }

    /// Aborts any in-flight recording without transcribing. Called when the card
    /// is dismissed so the audio session and state never leak into a stuck spinner.
    /// The spoken audio never outlives the screen that captured it. Called from
    /// both exits so an abandoned recording cannot sit in tmp either.
    private func discardRecording() {
        try? FileManager.default.removeItem(at: recordingURL)
    }

    func cancel() {
        stopMetering()
        discardRecording()
        recorder?.stop()
        recorder = nil
        isRecording = false
        isTranscribing = false
        try? AVAudioSession.sharedInstance().setActive(false,
            options: .notifyOthersOnDeactivation)
    }

    /// Stops recording, transcribes the audio, and returns the match percentage.
    /// Stops, transcribes, and deletes the audio.
    ///
    /// The recording is a means to a word match and nothing else, so it does
    /// not outlive the check — see `discardRecording`.
    func stopAndTranscribe() async -> Double {
        stopMetering()
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false,
            options: .notifyOthersOnDeactivation)

        isTranscribing = true
        defer { isTranscribing = false }

        let pct = await transcribeRecording()
        matchPercentage = pct
        discardRecording()
        return pct
    }

    // MARK: - Transcription

    private func transcribeRecording() async -> Double {
        guard FileManager.default.fileExists(atPath: recordingURL.path) else { return 0 }
        guard let recognizer = recognizer, recognizer.isAvailable else { return 0 }

        let request = SFSpeechURLRecognitionRequest(url: recordingURL)
        request.shouldReportPartialResults = false
        // Opt-in per call. On-device keeps the audio on the phone but can be
        // less accurate than Apple's server recognition, so the shipped
        // personal-declaration flow keeps the server path it was tuned against
        // and only new callers ask for on-device.
        if preferOnDeviceRecognition && recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let capturedWords = declarationWords

        return await withCheckedContinuation { continuation in
            // SFSpeechRecognitionTask can fire its callback multiple times, and
            // on short/silent/empty audio (some iOS versions) it may never fire
            // an `.isFinal` result and never error. Resuming a continuation twice
            // is a runtime trap (crash); never resuming hangs the caller forever
            // (the card sticks on the "Analyzing…" spinner with no way out). The
            // lock-guarded `resumed` flag makes the resume-exactly-once safe across
            // the recognizer's arbitrary callback queue and the timeout below.
            let lock = NSLock()
            var resumed = false
            var task: SFSpeechRecognitionTask?

            func finish(_ value: Double) {
                lock.lock()
                let already = resumed
                resumed = true
                lock.unlock()
                guard !already else { return }
                task?.cancel()
                continuation.resume(returning: value)
            }

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let final = result, final.isFinal {
                    let transcription = final.bestTranscription.formattedString
                    let (pct, indices) = Self.computeMatch(transcription: transcription,
                                                           declarationWords: capturedWords)
                    Task { @MainActor [weak self] in
                        self?.matchedIndices = indices
                    }
                    finish(pct)
                } else if error != nil {
                    finish(0)
                }
                // Non-final, no error → partial callback; wait for final or timeout.
            }

            // Safety net: if the recognizer never returns a final result and never
            // errors, resolve as a miss after 8s rather than leaving the UI frozen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                finish(0)
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
