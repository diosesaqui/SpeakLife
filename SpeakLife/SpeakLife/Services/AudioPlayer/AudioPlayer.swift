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
    private(set) var isPausedInBackground = false  // Made readable externally
    private var savedPlaybackTime: TimeInterval = 0
    private var lastBackgroundTime: Date?
    var isPlaying = false
    
    var currentArtist: String?
    var currentTitle: String?
    
    // Failsafe timer to kill audio after backgrounding
    private var backgroundKillTimer: Timer?
    
    private override init() {
           super.init()
           NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
           NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
           NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
           NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
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
    
    
    @objc private func appDidEnterBackground() {
            // Cancel any existing timer
            backgroundKillTimer?.invalidate()
            backgroundKillTimer = nil
            
            // Record when we entered background
            lastBackgroundTime = Date()
            
            // Pause background music when entering background (can resume later)
            if isPlaying {
                isPausedInBackground = true
                savedPlaybackTime = audioPlayer?.currentTime ?? 0
                pauseMusic()
                print("⏸️ Background music paused on entering background")
            }
            
            // Only deactivate audio session if NO content audio is playing
            // Content audio (sermons/lessons) should continue in background
            if !AudioPlayerViewModel.hasActiveAudio {
                // Deactivate audio session to prevent background music from randomly playing
                // This is the KEY to preventing random playback while backgrounded
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    print("🔇 Audio session deactivated (no content audio playing)")
                } catch {
                    print("❌ Failed to deactivate audio session: \(error)")
                }
            } else {
                print("🎵 Audio session remains active for content audio playback")
            }
            
            // Failsafe: Set a timer to completely stop music if still in background after 30 seconds
            // This prevents any zombie audio if app gets partially woken
            backgroundKillTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.audioPlayer != nil {
                    self.stopMusic()
                    self.isPausedInBackground = false
                    print("⏰ Failsafe: Stopped music after 30 seconds in background")
                }
            }
        }

        @objc private func appWillEnterForeground() {
            // Cancel the background kill timer since we're back
            backgroundKillTimer?.invalidate()
            backgroundKillTimer = nil
            
            // Check how long we've been in background
            var shouldAllowResume = false
            if let backgroundTime = lastBackgroundTime {
                let timeInBackground = Date().timeIntervalSince(backgroundTime)
                print("⏱️ App was in background for \(timeInBackground) seconds")
                
                // Allow resume if we were backgrounded for less than 5 minutes
                // and music was paused when we went to background
                if timeInBackground < 300 && isPausedInBackground {
                    shouldAllowResume = true
                } else if timeInBackground > 300 {
                    // Been backgrounded too long, clear everything
                    stopMusic()
                    print("🧹 Cleanup after extended background period")
                }
            }
            
            lastBackgroundTime = nil
            
            // Resume music if appropriate and user preference allows
            if shouldAllowResume && isPausedInBackground {
                // Will be resumed by SpeakLifeApp if user preference is enabled
                print("✅ Background music can be resumed if user preference allows")
            }
            
            isPausedInBackground = false
            savedPlaybackTime = 0
        }
        
        @objc private func appWillResignActive() {
            // App is becoming inactive (notification center, control center, etc.)
            // Don't pause audio - let it continue playing
        }
        
        @objc private func appDidBecomeActive() {
            // App became active again from inactive state
            // Don't need to do anything special here
        }


    func playSound(files: [MusicResources]) {
        // Prevent playing if we're not in the foreground
        guard UIApplication.shared.applicationState == .active else {
            print("⚠️ Preventing background music playback - app is not active")
            return
        }
        
        // Clear any stale background flags before playing
        isPausedInBackground = false
        savedPlaybackTime = 0
        lastBackgroundTime = nil
        
        // Setup audio session for background playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            // Failed to set up audio session
        }
        
        self.audioFiles = files.shuffled()
        self.currentFileIndex = 0
        if audioFiles.isEmpty {
            return
        }
        let type = audioFiles[currentFileIndex].type
        currentArtist = audioFiles[currentFileIndex].artist
        currentTitle = audioFiles[currentFileIndex].name
        playFile(type: type)
    }

    private func playFile(type: String) {
        // Double-check we're in foreground before playing
        guard UIApplication.shared.applicationState == .active else {
            print("⚠️ Preventing playFile - app is not active")
            stopMusic()
            return
        }
        
        guard !audioFiles.isEmpty else { return }
        let name = audioFiles[currentFileIndex].name
        if let path = Bundle.main.path(forResource: name, ofType: type) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                audioPlayer?.delegate = self
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Final check before playing
                    if UIApplication.shared.applicationState == .active {
                        self.audioPlayer?.prepareToPlay()
                        self.audioPlayer?.play()
                        self.isPlaying = true
                    } else {
                        self.stopMusic()
                    }
                }
            } catch {
                // Unable to locate audio file
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Check if app is in foreground before continuing playback
        let appState = UIApplication.shared.applicationState
        
        // Only continue playing if ALL conditions are met:
        // 1. Playback was successful
        // 2. We're actively playing
        // 3. App is in foreground
        // 4. No content audio is playing
        if flag && isPlaying && appState == .active && !AudioPlayerViewModel.hasActiveAudio {
            currentFileIndex = (currentFileIndex + 1) % audioFiles.count
            playFile(type: "mp3") // Assuming all files are mp3
        } else {
            // Stop everything if any condition fails
            stopMusic()
        }
    }
    
    func pauseMusic() {
        DispatchQueue.main.async { [weak self] in
            self?.audioPlayer?.pause()
        }
        isPlaying = false
        isPausedInBackground = false  // Clear any stale background state
    }
    
    func stopMusic() {
        // Immediately stop and completely release all audio resources
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Clear ALL state to prevent any possibility of resurrection
        isPlaying = false
        isPausedInBackground = false
        savedPlaybackTime = 0
        audioFiles = []
        currentFileIndex = 0
        currentArtist = nil
        currentTitle = nil
        
        // Deactivate audio session if no content audio is playing
        if !AudioPlayerViewModel.hasActiveAudio {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    func playMusic() {
        // Prevent playing if we're not in the foreground
        guard UIApplication.shared.applicationState == .active else {
            print("⚠️ Preventing playMusic - app is not active")
            return
        }
        
        // Only play if we have audio files loaded
        guard !audioFiles.isEmpty else { return }
        
        // If audio player was released (after background/suspension), recreate it
        if audioPlayer == nil && currentFileIndex < audioFiles.count {
            let type = audioFiles[currentFileIndex].type
            playFile(type: type)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Final check before playing
                if UIApplication.shared.applicationState == .active {
                    self.audioPlayer?.play()
                    self.isPlaying = true
                } else {
                    self.stopMusic()
                }
            }
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
