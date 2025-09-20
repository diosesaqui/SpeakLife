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
    
    func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45

        // Adjust pitch (default is 1.0, range: 0.5 to 2.0)
        utterance.pitchMultiplier = 1.2

        // Adjust volume (default is 1.0, range: 0.0 to 1.0)
        utterance.volume = 1.0
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { DispatchQueue.main.async {
        AudioPlayerService.shared.playMusic()
        self.isSpeaking = false
        }
    }
    
    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
}

