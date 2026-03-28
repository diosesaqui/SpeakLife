//
//  SpeechCoordinator.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 9/18/24.
//

import AVFoundation

class SpeechCoordinator: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking: Bool = false

    override init() {
        super.init()
        configureAudioSession()
        synthesizer.delegate = self
    }

    // MARK: - Voice Selection

    /// Returns the best available English voice for the given gender.
    /// Priority: Premium (iOS 17+) → Enhanced (iOS 16+) → system default.
    func bestVoice(gender: AVSpeechSynthesisVoiceGender = .female) -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let candidates = allVoices.filter {
            $0.language.hasPrefix("en-US") && $0.gender == gender
        }

        // iOS 17+ Premium neural voices (highest quality)
        if let premium = candidates.first(where: { $0.quality == .premium }) {
            print("🎙️ Using Premium voice: \(premium.name)")
            return premium
        }

        // iOS 16+ Enhanced neural voices (still much better than default)
        if let enhanced = candidates.first(where: { $0.quality == .enhanced }) {
            print("🎙️ Using Enhanced voice: \(enhanced.name)")
            return enhanced
        }

        // System default fallback
        print("🎙️ Falling back to default en-US voice")
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - Speech

    func speakText(_ text: String, gender: AVSpeechSynthesisVoiceGender = .female) {
        let utterance = AVSpeechUtterance(string: text)

        // Use the best available neural voice; fall back gracefully
        utterance.voice = bestVoice(gender: gender)
            ?? AVSpeechSynthesisVoice(language: "en-US")

        // Slightly slower than natural speech so affirmations land clearly
        utterance.rate = 0.48

        // Neutral pitch — enhanced/premium voices already sound natural
        utterance.pitchMultiplier = 1.0

        utterance.volume = 1.0

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            AudioPlayerService.shared.playMusic()
            self.isSpeaking = false
        }
    }

    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
}
