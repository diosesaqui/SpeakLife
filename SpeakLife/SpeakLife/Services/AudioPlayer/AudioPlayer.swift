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
            // Completely stop and clean up audio when entering background
            // This prevents any chance of audio continuing after backgrounding
            audioPlayer?.stop()
            audioPlayer = nil
            
            // Reset all state to ensure fresh start when app returns
            isPausedInBackground = false
            savedPlaybackTime = 0
            isPlaying = false
            audioFiles = []
            currentFileIndex = 0
            
            // Deactivate audio session to ensure no background audio continues
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        @objc private func appWillEnterForeground() {
            // Ensure clean state when returning from background/suspension
            isPausedInBackground = false
            savedPlaybackTime = 0
            isPlaying = false
            
            // Audio player was released in background, will be recreated when needed
            audioPlayer = nil
            // Note: Background music will be restarted by SpeakLifeApp if enabled
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
        if flag && isPlaying {  // Only continue if we're actively playing
            currentFileIndex = (currentFileIndex + 1) % audioFiles.count
            playFile(type: "mp3") // Assuming all files are mp3
        } else {
            // Stop playback if we're not actively playing
            isPlaying = false
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
        DispatchQueue.main.async { [weak self] in
            self?.audioPlayer?.stop()
            self?.audioPlayer = nil
        }
        isPlaying = false
        isPausedInBackground = false
        savedPlaybackTime = 0
        audioFiles = []
        
        // Don't deactivate audio session - other audio might be playing
        // The session will be managed by the audio content player
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
