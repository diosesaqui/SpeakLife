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
    private var isPausedInBackground = false
    private var savedPlaybackTime: TimeInterval = 0
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
            
            // Only stop BACKGROUND MUSIC when entering background
            // Content audio (lessons) should continue playing
            
            // Check if this is actually playing background music (not content audio)
            if isPlaying && !AudioPlayerViewModel.hasActiveAudio {
                // This is background music - stop it completely
                stopMusic()
            }
            
            // Set a failsafe timer to absolutely kill any background music after 60 seconds
            // This prevents any possibility of music playing hours later
            backgroundKillTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
                self?.stopMusic()
                print("⏰ Failsafe: Killed background music after 60 seconds in background")
            }
        }

        @objc private func appWillEnterForeground() {
            // Cancel the background kill timer since we're back
            backgroundKillTimer?.invalidate()
            backgroundKillTimer = nil
            
            // Ensure clean state when returning from background/suspension
            isPausedInBackground = false
            savedPlaybackTime = 0
            isPlaying = false
            
            // Audio player was released in background, will be recreated when needed
            audioPlayer = nil
            // Background music will NOT be automatically restarted
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
        // Clear any stale background flags before playing
        isPausedInBackground = false
        savedPlaybackTime = 0
        
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
        guard !audioFiles.isEmpty else { return }
        let name = audioFiles[currentFileIndex].name
        if let path = Bundle.main.path(forResource: name, ofType: type) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                audioPlayer?.delegate = self
                DispatchQueue.main.async { [weak self] in
                    self?.audioPlayer?.prepareToPlay()
                    self?.audioPlayer?.play()
                }
                isPlaying = true
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
        // Only play if we have audio files loaded
        guard !audioFiles.isEmpty else { return }
        
        // If audio player was released (after background/suspension), recreate it
        if audioPlayer == nil && currentFileIndex < audioFiles.count {
            let type = audioFiles[currentFileIndex].type
            playFile(type: type)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.audioPlayer?.play()
            }
            isPlaying = true
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
