//
//  AudioPlayer.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 1/20/24.
//

import AVFoundation
import UIKit

class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerService()
    private var audioPlayer: AVAudioPlayer?
    private var audioFiles: [MusicResources] = []
    private var currentFileIndex = 0
    var isPlaying = false
    
    var currentArtist: String?
    var currentTitle: String?
    
    // Smart pause/resume for background interruptions
    private var backgroundStopTimer: Timer?
    private var wasPausedForBackground = false
    private let backgroundStopDelay: TimeInterval = 15.0 // 15 seconds
    
    private override init() {
           super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        // Don't activate audio session on init - only when actually playing
        // This prevents audio session conflicts
    }

       deinit {
           NotificationCenter.default.removeObserver(self)
       }
    

    func playSound(files: [MusicResources]) {
        // If music is already playing with the same files, don't restart
        if isPlaying && !audioFiles.isEmpty {
            return
        }
        
        // Stop any existing music first
        stopMusic()
        
        
        // Check if content audio is active before starting
        guard !AudioPlayerViewModel.hasActiveAudio else {
            return
        }
        
        // Setup audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            return
        }
        
        // Shuffle and play
        self.audioFiles = files.shuffled()
        self.currentFileIndex = 0
        
        guard !audioFiles.isEmpty else { 
            return 
        }
        
        let type = audioFiles[currentFileIndex].type
        currentArtist = audioFiles[currentFileIndex].artist
        currentTitle = audioFiles[currentFileIndex].name
        
        playFile(type: type)
    }

    private func playFile(type: String) {
        guard !audioFiles.isEmpty else { 
            return 
        }
        guard currentFileIndex < audioFiles.count else { 
            return 
        }
        
        let name = audioFiles[currentFileIndex].name
        
        guard let path = Bundle.main.path(forResource: name, ofType: type) else {
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Check once more before playing
            guard !AudioPlayerViewModel.hasActiveAudio else {
                stopMusic()
                return
            }
            
            // CRITICAL: Check app state right before playing to prevent background playback
            guard UIApplication.shared.applicationState == .active else {
                stopMusic()
                return
            }
            
            audioPlayer?.play()
            isPlaying = true
        } catch {
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        // Only continue if playback was successful and we're still supposed to be playing
        guard flag else {
            // Warning: 
            print("⚠️ Playback did not finish successfully - stopping")
            stopMusic()
            return
        }
        
        guard isPlaying else {
            print("ℹ️ Music was stopped during playback - not continuing")
            return
        }
        
        // Check if app is in foreground before continuing to next song
        let appState = UIApplication.shared.applicationState
        guard appState == .active else {
            // Warning: 
            print("⚠️ App is not active (state: \(appState.rawValue)) - stopping background music")
            stopMusic()
            return
        }
        
        // Check if we should continue playing
        guard !AudioPlayerViewModel.hasActiveAudio else {
            print("ℹ️ Content audio is active, stopping background music")
            stopMusic()
            return
        }
        
        // Ensure we have files to play
        guard !audioFiles.isEmpty else {
            // Warning: 
            print("⚠️ No audio files available - stopping")
            stopMusic()
            return
        }
        
        // Move to next song
        currentFileIndex = (currentFileIndex + 1) % audioFiles.count
        
        // Get the file type from the current file
        let type = audioFiles[currentFileIndex].type
        currentArtist = audioFiles[currentFileIndex].artist
        currentTitle = audioFiles[currentFileIndex].name
        
        // Final check before playing next file to prevent race conditions
        guard UIApplication.shared.applicationState == .active else {
            stopMusic()
            return
        }
        
        playFile(type: type)
    }
    
    func pauseMusic() {
        audioPlayer?.pause()
        isPlaying = false
        print("⏸️ Music paused")
    }
    
    // Smart pause for background interruptions - won't reset music
    func pauseForBackground() {
        guard isPlaying else { 
            return 
        }
        
        // Don't pause again if already paused for background
        if wasPausedForBackground {
            return
        }
        
        audioPlayer?.pause()
        wasPausedForBackground = true
        isPlaying = false
        
        
        // Start timer to stop music after delay
        backgroundStopTimer?.invalidate()
        backgroundStopTimer = Timer.scheduledTimer(withTimeInterval: backgroundStopDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.wasPausedForBackground {
                self.stopMusic()
            }
        }
    }
    
    // Smart resume for returning from background
    func resumeFromBackground() -> Bool {
        
        // Cancel the background stop timer
        backgroundStopTimer?.invalidate()
        backgroundStopTimer = nil
        
        // Only resume if it was paused for background and player still exists
        guard wasPausedForBackground, let player = audioPlayer else {
            wasPausedForBackground = false
            return false // No music to resume
        }
        
        wasPausedForBackground = false
        
        // We're already being called from the .active case, so no need to check app state again
        player.play()
        isPlaying = true
        return true // Successfully resumed
    }
    
    func stopMusic() {
        // Cancel any background timers
        backgroundStopTimer?.invalidate()
        backgroundStopTimer = nil
        wasPausedForBackground = false
        
        // Stop and clear everything
        audioPlayer?.stop()
        audioPlayer?.delegate = nil  // Remove delegate to prevent callbacks
        audioPlayer = nil
        isPlaying = false
        audioFiles = []
        currentFileIndex = 0
        currentArtist = nil
        currentTitle = nil
        
        // Always deactivate audio session when stopping background music
        // This ensures no audio can play in background
        if !AudioPlayerViewModel.hasActiveAudio {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("❌ Failed to deactivate audio session: \(error)")
            }
        }
        
        print("⏹️ Music stopped and cleaned up")
    }
    
    func playMusic() {
        // ONLY resume if there's an existing player and app is active
        guard let player = audioPlayer else {
            // Warning: 
            print("⚠️ No active music player to resume")
            return
        }
        
        // Don't resume if app is not active
        guard UIApplication.shared.applicationState == .active else {
            // Warning: 
            print("⚠️ App is not active - not resuming music")
            return
        }
        
        player.play()
        isPlaying = true
        print("▶️ Music resumed")
    }
    
    // Use this method when you want to resume OR start music
    func resumeOrStartMusic(files: [MusicResources]) {
        // First try to resume existing music
        if audioPlayer != nil {
            playMusic()
        } else {
            // Only start new music if we're not in background and not playing content audio
            guard !AudioPlayerViewModel.hasActiveAudio else {
                // Warning: 
                print("⚠️ Content audio is active, not starting background music")
                return
            }
            
            // Start fresh playback
            playSound(files: files)
        }
    }
    
    

    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .began {
            // Audio session was interrupted
            audioPlayer?.pause()
            isPlaying = false
        } else if type == .ended {
            // Interruption ended - don't automatically resume
            // User must explicitly press play to resume
            // This prevents unwanted audio playback
        }
    }
}
