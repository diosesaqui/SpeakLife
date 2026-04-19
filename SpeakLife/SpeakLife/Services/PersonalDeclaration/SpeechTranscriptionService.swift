//
//  SpeechTranscriptionService.swift
//  SpeakLife
//

import Foundation
import Speech
import AVFoundation

final class SpeechTranscriptionService: SpeechTranscriptionProtocol {
    private var audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
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
        // Clean up any previous session that didn't stop cleanly
        teardown()
        latestTranscription = ""

        let node = audioEngine.inputNode

        // Remove any existing tap to prevent installTap crash on re-entry
        node.removeTap(onBus: 0)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                self?.latestTranscription = result.bestTranscription.formattedString
            }
            if error != nil {
                self?.teardown()
            }
        }

        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() async -> String {
        let result = latestTranscription
        teardown()
        return result
    }

    // MARK: - Teardown

    private func teardown() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
    }
}
