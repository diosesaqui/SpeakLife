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
            print("🎵 Background music already playing - skipping restart")
            return
        }
        
        // Stop any existing music first
        stopMusic()
        
        print("🎵 Starting background music with \(files.count) files")
        
        // Setup audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
        
        // Shuffle and play
        self.audioFiles = files.shuffled()
        self.currentFileIndex = 0
        
        guard !audioFiles.isEmpty else { return }
        
        let type = audioFiles[currentFileIndex].type
        currentArtist = audioFiles[currentFileIndex].artist
        currentTitle = audioFiles[currentFileIndex].name
        
        playFile(type: type)
    }

    private func playFile(type: String) {
        guard !audioFiles.isEmpty else { return }
        guard currentFileIndex < audioFiles.count else { return }
        
        let name = audioFiles[currentFileIndex].name
        print("🎵 Playing: \(name) (index \(currentFileIndex))")
        
        guard let path = Bundle.main.path(forResource: name, ofType: type) else {
            print("❌ Could not find file: \(name).\(type)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            print("✅ Playback started")
        } catch {
            print("❌ Failed to play file: \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🎵 Song finished playing (success: \(flag), isPlaying: \(isPlaying))")
        
        // Only continue if playback was successful and we're still supposed to be playing
        guard flag else {
            print("⚠️ Playback did not finish successfully - stopping")
            stopMusic()
            return
        }
        
        guard isPlaying else {
            print("ℹ️ Music was stopped during playback - not continuing")
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
            print("⚠️ No audio files available - stopping")
            stopMusic()
            return
        }
        
        // Move to next song
        currentFileIndex = (currentFileIndex + 1) % audioFiles.count
        print("🎵 Moving to next song (index \(currentFileIndex) of \(audioFiles.count))")
        
        // Get the file type from the current file
        let type = audioFiles[currentFileIndex].type
        currentArtist = audioFiles[currentFileIndex].artist
        currentTitle = audioFiles[currentFileIndex].name
        
        playFile(type: type)
    }
    
    func pauseMusic() {
        audioPlayer?.pause()
        isPlaying = false
        print("⏸️ Music paused")
    }
    
    func stopMusic() {
        // Stop and clear everything
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        audioFiles = []
        currentFileIndex = 0
        currentArtist = nil
        currentTitle = nil
        
        // Deactivate audio session
        if !AudioPlayerViewModel.hasActiveAudio {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        
        print("⏹️ Music stopped")
    }
    
    func playMusic() {
        // ONLY resume if there's an existing player - never start new playback
        guard let player = audioPlayer else {
            print("⚠️ No active music player to resume")
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
