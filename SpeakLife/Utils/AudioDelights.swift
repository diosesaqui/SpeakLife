//
//  AudioDelights.swift
//  SpeakLife
//
//  Premium audio feedback system for enhanced user experience
//

import AVFoundation
import SwiftUI
import CoreGraphics

// MARK: - Audio Delight Manager

final class AudioDelightManager: ObservableObject {
    static let shared = AudioDelightManager()
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var isEnabled: Bool = true
    
    // Audio file names (these would be added to the bundle)
    private enum SoundFile: String, CaseIterable {
        // Gentle Sounds
        case gentleChime = "gentle_chime"
        case softBell = "soft_bell"
        case warmTone = "warm_tone"
        case peacefulBell = "peaceful_bell"
        
        // Success Sounds
        case successChime = "success_chime"
        case upliftingArpeggio = "uplifting_arpeggio"
        case victoryBell = "victory_bell"
        case achievementTone = "achievement_tone"
        
        // Celebration Sounds
        case celebrationFanfare = "celebration_fanfare"
        case joyfulChimes = "joyful_chimes"
        case triumphantBells = "triumphant_bells"
        case festiveArpeggio = "festive_arpeggio"
        
        // Prayer/Meditation Sounds
        case prayerBell = "prayer_bell"
        case meditationChime = "meditation_chime"
        case spiritualTone = "spiritual_tone"
        case sacredBell = "sacred_bell"
        
        // Interaction Sounds
        case buttonTap = "button_tap"
        case cardFlip = "card_flip"
        case heartbeat = "heartbeat_sound"
        case favoriteAdd = "favorite_add"
        
        // Notification Sounds
        case morningGreeting = "morning_greeting"
        case eveningReflection = "evening_reflection"
        case goalComplete = "goal_complete"
        
        var fileExtension: String {
            return "wav" // or "m4a" for compressed audio
        }
    }
    
    private init() {
        setupAudioSession()
        preloadSounds()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func preloadSounds() {
        for sound in SoundFile.allCases {
            loadSound(sound)
        }
    }
    
    private func loadSound(_ soundFile: SoundFile) {
        guard let url = Bundle.main.url(
            forResource: soundFile.rawValue,
            withExtension: soundFile.fileExtension
        ) else {
            // Warning: 
            print("⚠️ Audio file not found: \(soundFile.rawValue)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = 0.7
            audioPlayers[soundFile.rawValue] = player
        } catch {
            print("❌ Failed to load sound \(soundFile.rawValue): \(error)")
        }
    }
    
    // MARK: - Playback Control
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "audioDelightsEnabled")
    }
    
    func isAudioEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "audioDelightsEnabled") != false // Default to true
    }
    
    private func playSound(_ soundFile: SoundFile, volume: Float = 0.7) {
        guard isEnabled && isAudioEnabled() else { return }
        
        guard let player = audioPlayers[soundFile.rawValue] else {
            // Warning: 
            print("⚠️ Audio player not found for: \(soundFile.rawValue)")
            return
        }
        
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
    
    // MARK: - Public Sound Methods
    
    // Basic Interactions
    func playButtonTap() {
        playSound(.buttonTap, volume: 0.3)
    }
    
    func playCardFlip() {
        playSound(.cardFlip, volume: 0.4)
    }
    
    func playHeartbeat() {
        playSound(.heartbeat, volume: 0.5)
    }
    
    // Success & Achievements
    func playGentleSuccess() {
        playSound(.gentleChime, volume: 0.6)
    }
    
    func playMediumSuccess() {
        playSound(.successChime, volume: 0.7)
    }
    
    func playMajorSuccess() {
        playSound(.upliftingArpeggio, volume: 0.8)
    }
    
    func playAchievement() {
        playSound(.achievementTone, volume: 0.9)
    }
    
    // Celebrations
    func playCelebration() {
        playSound(.celebrationFanfare, volume: 0.8)
    }
    
    func playJoyfulMoment() {
        playSound(.joyfulChimes, volume: 0.7)
    }
    
    func playTriumph() {
        playSound(.triumphantBells, volume: 0.9)
    }
    
    // Prayer & Meditation
    func playPrayerStart() {
        playSound(.prayerBell, volume: 0.6)
    }
    
    func playMeditation() {
        playSound(.meditationChime, volume: 0.5)
    }
    
    func playSacredMoment() {
        playSound(.sacredBell, volume: 0.7)
    }
    
    // Favorites & Hearts
    func playFavoriteAdded() {
        playSound(.favoriteAdd, volume: 0.6)
    }
    
    func playHeartPulse() {
        playSound(.heartbeat, volume: 0.4)
    }
    
    // Time-based
    func playMorningGreeting() {
        playSound(.morningGreeting, volume: 0.6)
    }
    
    func playEveningReflection() {
        playSound(.eveningReflection, volume: 0.5)
    }
    
    func playGoalComplete() {
        playSound(.goalComplete, volume: 0.8)
    }
    
    // MARK: - Contextual Audio
    
    func playForCategory(_ category: String) {
        switch category.lowercased() {
        case "faith", "grace", "praise":
            playSacredMoment()
        case "love", "gratitude", "joy":
            playJoyfulMoment()
        case "peace", "rest":
            playMeditation()
        case "strength", "confidence", "destiny":
            playAchievement()
        default:
            playGentleSuccess()
        }
    }
    
    func playForStreakMilestone(_ days: Int) {
        switch days {
        case 1...6:
            playGentleSuccess()
        case 7:
            playMediumSuccess()
        case 14, 21:
            playMajorSuccess()
        case 30:
            playAchievement()
        case 50, 100:
            playTriumph()
        default:
            if days % 50 == 0 {
                playTriumph()
            } else if days % 10 == 0 {
                playMajorSuccess()
            } else {
                playGentleSuccess()
            }
        }
    }
    
    func playForCelebration(_ type: CelebrationManager.CelebrationType) {
        switch type {
        case .firstAffirmation, .firstStreak, .firstFavorite, .firstJournal:
            playGentleSuccess()
        case .streak7, .dailyGoalComplete:
            playMediumSuccess()
        case .streak30, .weeklyGoalComplete:
            playMajorSuccess()
        case .streak100, .monthlyGoalComplete, .newRecord:
            playTriumph()
        case .streak365:
            // Epic celebration - multiple sounds
            playTriumph()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.playCelebration()
            }
        case .birthday, .holiday, .newYear:
            playCelebration()
        case .premiumUpgrade:
            playAchievement()
        case .shareSuccess:
            playJoyfulMoment()
        }
    }
    
    // MARK: - Audio Sequences
    
    func playSuccessSequence() {
        playGentleSuccess()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.playMediumSuccess()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.playMajorSuccess()
        }
    }
    
    func playHeartbeatSequence() {
        playHeartPulse()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.playHeartPulse()
        }
    }
    
    func playPrayerSequence() {
        playPrayerStart()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.playMeditation()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.playSacredMoment()
        }
    }
}

// MARK: - Audio Delight View Modifier

struct AudioDelightModifier: ViewModifier {
    let soundAction: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                soundAction()
            }
    }
}

// MARK: - Breathing Sound Generator

class BreathingSoundGenerator: ObservableObject {
    private var breathingTimer: Timer?
    private let audioManager = AudioDelightManager.shared
    @Published var isBreathing = false
    
    func startBreathing(duration: Double = 4.0) {
        guard !isBreathing else { return }
        
        isBreathing = true
        breathingTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { _ in
            self.audioManager.playMeditation()
        }
        
        // Play initial sound
        audioManager.playPrayerStart()
    }
    
    func stopBreathing() {
        isBreathing = false
        breathingTimer?.invalidate()
        breathingTimer = nil
    }
}

// MARK: - Spatial Audio Effects

class SpatialAudioManager: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var environmentNode: AVAudioEnvironmentNode
    private var playerNodes: [AVAudioPlayerNode] = []
    
    init() {
        audioEngine = AVAudioEngine()
        environmentNode = AVAudioEnvironmentNode()
        setupSpatialAudio()
    }
    
    private func setupSpatialAudio() {
        // Attach environment node
        audioEngine.attach(environmentNode)
        
        // Connect to output
        audioEngine.connect(
            environmentNode,
            to: audioEngine.mainMixerNode,
            format: nil
        )
        
        // Configure 3D environment
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerVectorOrientation = AVAudio3DVectorOrientation(
            forward: AVAudio3DVector(x: 0, y: 0, z: -1),
            up: AVAudio3DVector(x: 0, y: 1, z: 0)
        )
        
        do {
            try audioEngine.start()
        } catch {
            print("❌ Failed to start spatial audio engine: \(error)")
        }
    }
    
    func playPositionalSound(
        fileName: String,
        position: AVAudio3DPoint = AVAudio3DPoint(x: 0, y: 0, z: 0),
        volume: Float = 1.0
    ) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "wav") else {
            return
        }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let playerNode = AVAudioPlayerNode()
            
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: environmentNode, format: audioFile.processingFormat)
            
            playerNode.position = position
            playerNode.volume = volume
            
            playerNode.scheduleFile(audioFile, at: nil) {
                DispatchQueue.main.async {
                    self.audioEngine.detach(playerNode)
                    if let index = self.playerNodes.firstIndex(of: playerNode) {
                        self.playerNodes.remove(at: index)
                    }
                }
            }
            
            playerNodes.append(playerNode)
            playerNode.play()
            
        } catch {
            print("❌ Failed to play spatial audio: \(error)")
        }
    }
}

// MARK: - View Extensions

extension View {
    func audioDelight(sound: @escaping () -> Void) -> some View {
        self.modifier(AudioDelightModifier(soundAction: sound))
    }
    
    func buttonTapAudio() -> some View {
        self.audioDelight {
            AudioDelightManager.shared.playButtonTap()
        }
    }
    
    func successAudio() -> some View {
        self.audioDelight {
            AudioDelightManager.shared.playGentleSuccess()
        }
    }
    
    func heartbeatAudio() -> some View {
        self.audioDelight {
            AudioDelightManager.shared.playHeartbeatSequence()
        }
    }
    
    func celebrationAudio() -> some View {
        self.audioDelight {
            AudioDelightManager.shared.playCelebration()
        }
    }
}