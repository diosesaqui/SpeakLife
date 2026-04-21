//
//  SpeechTranscriptionService.swift
//  SpeakLife
//
//  Uses AVAudioRecorder + SFSpeechURLRecognitionRequest.
//  AVAudioEngine/installTap was removed because it raises an uncatchable
//  NSException (AUGraphNodeBaseV3::CreateRecordingTap) on certain devices/OS
//  versions, crashing the app instantly.
//

import Foundation
import Speech
import AVFoundation

final class SpeechTranscriptionService: SpeechTranscriptionProtocol {

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)

    private(set) var isRecording = false

    // MARK: - Permission

    func requestPermission() async -> Bool {
        // 1. Speech recognition
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else { return false }

        // 2. Microphone — must be granted before AVAudioRecorder will record
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return micGranted
    }

    // MARK: - Recording

    func startRecording() async throws {
        teardown()

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
        audioRecorder?.record()
        recordingURL = url
        isRecording = true
    }

    // MARK: - Stop & Transcribe

    func stopRecording() async -> String {
        guard let url = recordingURL else {
            teardown()
            return ""
        }

        audioRecorder?.stop()
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-fatal — continue with transcription
        }

        let transcription = await transcribe(url: url)
        teardown()
        return transcription
    }

    // MARK: - Transcription

    private func transcribe(url: URL) async -> String {
        guard let recognizer = recognizer, recognizer.isAvailable else { return "" }

        return await withCheckedContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false

            recognizer.recognitionTask(with: request) { result, error in
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if error != nil {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    // MARK: - Teardown

    private func teardown() {
        audioRecorder?.stop()
        audioRecorder = nil
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        isRecording = false
    }
}
