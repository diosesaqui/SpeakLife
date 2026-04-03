//
//  SpeechSynthesizer.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/7/23.
//

import Foundation
import AVFoundation

final class SpeechSynthesizer: ObservableObject {
    
    private let speechSynthesizer = AVSpeechSynthesizer()

    func speakText(_ text: String) {
       
        let speechUtterance = AVSpeechUtterance(string: text)
        
        // Set the voice to Siri's voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            speechUtterance.voice = voice
        }
        
        // Set the speech rate and volume (optional)
        speechUtterance.rate = 0.5
        speechUtterance.volume = 0.8
        
        // Start speaking the text
        speechSynthesizer.speak(speechUtterance)
    }
}






