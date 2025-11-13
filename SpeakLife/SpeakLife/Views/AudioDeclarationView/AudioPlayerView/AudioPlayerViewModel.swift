//
//  AudioPlayerViewModel.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 11/20/24.
//

import SwiftUI
import AVFoundation
import Combine
import MediaPlayer

final class AudioPlayerViewModel: NSObject, ObservableObject {
    // Static property to track if any content audio is playing globally
    static var hasActiveAudio: Bool = false
    private var backgroundTime: Date?
    
    @Published var isPlaying: Bool = false {
        didSet {
            // Update the static property
            AudioPlayerViewModel.hasActiveAudio = isPlaying
        }
    }
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var onRepeat = false
    @Published var currentTrack: String = ""
    @Published var subtitle: String = ""
    @Published var imageUrl: String = ""
    @Published var isBarVisible: Bool = false
    @Published var autoPlayAudio: Bool = false
    @Published var audioQueue: [AudioDeclaration] = []
    @Published var selectedItem: AudioDeclaration? = nil
    @Published var lastSelectedItem: AudioDeclaration?

    private var urlQueue: [URL] = []
    // Removed audioDeclarationViewModel reference - not needed

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
    private var hasPrefetchedNext = false
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        
        // Removed the problematic Combine publisher that was checking for end of playback
        // AVPlayer already handles this through AVPlayerItemDidPlayToEndTime notification
        
        setupRemoteCommands()
        setupBackgroundObservers()
    }
    
    private func setupBackgroundObservers() {
        // Audio content should continue playing in background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidEnterBackground() {
        // Record when we entered background
        backgroundTime = Date()
        
        // Content audio CAN continue playing in background if actively playing
        // But we need to ensure background music is stopped
        AudioPlayerService.shared.stopMusic()
        
        // Only maintain audio session if content is actively playing
        if isPlaying && player?.rate ?? 0 > 0 {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                // Re-enable the session to ensure background playback continues for content
                try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay])
                try audioSession.setActive(true)
            } catch {
                print("❌ Failed to maintain audio session for background: \(error)")
            }
            
            // Update the Now Playing info for lock screen controls
            updateNowPlayingInfo()
        } else {
            // If not actively playing content, deactivate audio session
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        // Check how long we've been in background
        if let bgTime = backgroundTime {
            let timeInBackground = Date().timeIntervalSince(bgTime)
            print("⏱️ AudioPlayer was in background for \(timeInBackground) seconds")
            
            // If we've been backgrounded for more than 5 minutes, don't auto-resume
            if timeInBackground > 300 {
                // Stop everything to prevent zombie audio
                if isPlaying {
                    print("🛑 Stopping audio after extended background period")
                    togglePlayPause() // This will pause the audio properly
                }
                backgroundTime = nil
                return
            }
        }
        
        // Only resume if content audio was actively playing and we weren't suspended too long
        if isPlaying && player?.rate == 0 && AudioPlayerViewModel.hasActiveAudio {
            // This is content audio that should resume
            player?.play()
            updateNowPlayingInfo()
        }
        
        // Always ensure background music is stopped
        AudioPlayerService.shared.stopMusic()
        
        backgroundTime = nil
    }

    deinit {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        // Clean up all observers and stop all audio
        resetPlayer()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        // Ensure background music is stopped
        AudioPlayerService.shared.stopMusic()
    }


    func loadAudio(from url: URL, isSameItem: Bool) {
        hasPrefetchedNext = false
       // startMonitoringPlayback()
        

        if isSameItem { 
            // If same item and not playing, start playing
            if !isPlaying {
                if let audio = selectedItem {
                    AnalyticsService.shared.trackAudioPlayback(
                        audioId: audio.id,
                        audioTitle: audio.title,
                        action: .resumed,
                        metadata: [
                            "category": audio.tag ?? "unknown",
                            "duration": audio.duration,
                            "is_premium": audio.isPremium,
                            "playback_position": currentTime
                        ]
                    )
                }
                player?.play()
                isPlaying = true
            }
            return 
        }
        resetPlayer()
        
        // Stop background music first to avoid conflicts
        AudioPlayerService.shared.stopMusic()

        // Improved audio session setup with error handling for background playback
        do {
            // Configure for background audio playback
            let audioSession = AVAudioSession.sharedInstance()
            
            // Simulator-specific workaround for error -11800
            #if targetEnvironment(simulator)
            // Reset audio session first to clear any stale state
            try? audioSession.setActive(false, options: [])
            
            // Try multiple configurations for simulator compatibility
            do {
                // First try the simplest configuration
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
                print("✅ Audio session configured for simulator (basic mode)")
            } catch {
                // If that fails, try with mixWithOthers
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try audioSession.setActive(true, options: [])
                print("✅ Audio session configured for simulator (mixWithOthers mode)")
            }
            #else
            // Physical device configuration
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured for physical device")
            #endif
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            // For simulator, this is often not critical - audio might still work
            #if targetEnvironment(simulator)
            print("ℹ️ Note: Audio session errors are common in simulator but audio may still work")
            #endif
        }

        // Verify file exists at URL (important for simulator)
        if !FileManager.default.fileExists(atPath: url.path) {
            print("❌ Audio file does not exist at path: \(url.path)")
            return
        }
        
        // Check file size to ensure it's not empty
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int ?? 0
            print("📁 Audio file size: \(fileSize) bytes at: \(url.lastPathComponent)")
            if fileSize == 0 {
                print("❌ Audio file is empty")
                return
            }
        } catch {
            print("❌ Failed to check file attributes: \(error)")
        }
        
        // For simulator, skip complex asset validation that causes -11800 errors
        #if targetEnvironment(simulator)
        // Simulator: Just create the player directly
        print("📱 Simulator detected - using simplified audio loading")
        
        // Ensure the URL is properly formatted for simulator
        let fileURL: URL
        if url.isFileURL {
            fileURL = url
        } else {
            fileURL = URL(fileURLWithPath: url.path)
        }
        print("🎵 Loading audio from: \(fileURL)")
        
        self.createAndConfigurePlayer(with: fileURL)
        #else
        // Physical device: Full validation
        let asset = AVAsset(url: url)
        
        // Load the asset's tracks asynchronously to check if it's valid
        asset.loadValuesAsynchronously(forKeys: ["playable", "tracks"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                var error: NSError?
                let playableStatus = asset.statusOfValue(forKey: "playable", error: &error)
                let tracksStatus = asset.statusOfValue(forKey: "tracks", error: &error)
                
                if playableStatus == .failed || tracksStatus == .failed {
                    print("❌ Asset loading failed: \(error?.localizedDescription ?? "Unknown error")")
                    
                    // Try to re-download the file if it's corrupted
                    if let item = self.selectedItem {
                        self.handleCorruptedAudioFile(item: item, url: url)
                    }
                    return
                }
                
                if !asset.isPlayable || asset.tracks.isEmpty {
                    print("❌ Audio asset is not playable or has no tracks: \(url.lastPathComponent)")
                    
                    // Try to re-download the file
                    if let item = self.selectedItem {
                        self.handleCorruptedAudioFile(item: item, url: url)
                    }
                    return
                }
                
                // Asset is valid, create the player
                self.createAndConfigurePlayer(with: url)
            }
        }
        #endif
    }
    
    private func createAndConfigurePlayer(with url: URL) {
        #if targetEnvironment(simulator)
        // Simulator: Create player with PlayerItem for better compatibility
        let playerItem = AVPlayerItem(url: url)
        
        // Pre-load the item
        playerItem.preferredForwardBufferDuration = 5.0
        
        player = AVPlayer(playerItem: playerItem)
        
        // Set player properties for better simulator compatibility
        player?.automaticallyWaitsToMinimizeStalling = false
        player?.rate = 1.0
        
        // Don't add observer immediately - wait for item to be ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        }
        #else
        // Physical device: Standard initialization
        player = AVPlayer(url: url)
        
        // Add observer for player status
        player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        #endif
        
        // Wait for the asset to load before getting duration
        player?.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, let asset = self.player?.currentItem?.asset else { return }
                let duration = asset.duration
                if duration.isValid && !duration.isIndefinite {
                    self.duration = CMTimeGetSeconds(duration)
                }
            }
        }

        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = CMTimeGetSeconds(time)
            self.updateNowPlayingInfo()
        }
       
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
            guard let self = self else { return }

            if let audio = self.selectedItem {
                AnalyticsService.shared.trackAudioPlayback(
                    audioId: audio.id,
                    audioTitle: audio.title,
                    action: .completed,
                    metadata: [
                        "category": audio.tag ?? "unknown",
                        "duration": self.duration,
                        "repeat_enabled": self.onRepeat,
                        "playback_speed": self.playbackSpeed
                    ]
                )
            }
            
            if self.onRepeat {
                self.player?.seek(to: .zero)
                self.player?.play()
            }
//            else if !self.urlQueue.isEmpty {
//                playNextInQueue()
//                self.player?.seek(to: .zero)
//                self.isPlaying = false
//            }
            else {
                self.isPlaying = false
                self.player?.seek(to: .zero)
                
                // If audio finished while app is in background, deactivate audio session
                // This prevents zombie audio sessions that could allow random playback
                if UIApplication.shared.applicationState != .active {
                    do {
                        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                        print("🔇 Audio session deactivated - content finished while in background")
                    } catch {
                        print("❌ Failed to deactivate audio session after content finished: \(error)")
                    }
                }
            }
            self.updateNowPlayingInfo()
        }
        // Start playing when loading audio
        #if targetEnvironment(simulator)
        // Simulator: Delay play to allow player to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.player?.play()
            self?.isPlaying = true
        }
        #else
        // Physical device: Play immediately
        if let player = player {
            player.play()
        }
        isPlaying = true
        #endif
        
        if let audio = selectedItem {
            AnalyticsService.shared.trackAudioPlayback(
                audioId: audio.id,
                audioTitle: audio.title,
                action: .started,
                metadata: [
                    "category": audio.tag ?? "unknown",
                    "duration": audio.duration,
                    "is_premium": audio.isPremium,
                    "playback_speed": playbackSpeed,
                    "repeat_enabled": onRepeat
                ]
            )
        }
//        if let currentAudio = selectedItem {
//            ListenerMetricsService.shared.trackListen(
//                contentId: currentAudio.id,
//                contentType: .audio
//            )
//            print(selectedItem, currentAudio.id, "RWRW selected item")
//        }
        
        
        // Track listen event for metrics
      
        // Background music already stopped earlier in setup process
        updateNowPlayingInfo()

        
       
    }

    func togglePlayPause() {
        guard let player = player else { 
            return 
        }

        
        if isPlaying {
            if let audio = selectedItem {
                AnalyticsService.shared.trackAudioPlayback(
                    audioId: audio.id,
                    audioTitle: audio.title,
                    action: .paused,
                    metadata: [
                        "playback_position": currentTime,
                        "playback_progress": duration > 0 ? currentTime / duration : 0,
                        "category": audio.tag ?? "unknown"
                    ]
                )
            }
            player.pause()
            // DON'T automatically start background music when pausing content
            // AudioPlayerService.shared.playMusic() // REMOVED - This could cause unwanted playback
        } else {
            if let audio = selectedItem {
                AnalyticsService.shared.trackAudioPlayback(
                    audioId: audio.id,
                    audioTitle: audio.title,
                    action: .resumed,
                    metadata: [
                        "playback_position": currentTime,
                        "playback_progress": duration > 0 ? currentTime / duration : 0,
                        "category": audio.tag ?? "unknown"
                    ]
                )
            }
            // Stop background music when playing content audio
            AudioPlayerService.shared.stopMusic()
            player.play()
        }
        isPlaying.toggle()
        
        updateNowPlayingInfo()
    }
    
    private func handleCorruptedAudioFile(item: AudioDeclaration, url: URL) {
        print("🔄 Attempting to re-download corrupted audio file: \(item.title)")
        
        // Delete the corrupted file
        try? FileManager.default.removeItem(at: url)
        
        // Get the AudioDeclarationViewModel to re-download
        NotificationCenter.default.post(
            name: NSNotification.Name("RedownloadAudioFile"),
            object: nil,
            userInfo: ["item": item, "url": url]
        )
        
        // Reset player state
        resetPlayer()
        
        // Notify user about the issue (you might want to show an alert)
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            print("⚠️ Audio file was corrupted. Please try playing it again to re-download.")
        }
    }

    func seek(to time: Double) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: time, preferredTimescale: 1)
        
        if let audio = selectedItem {
            AnalyticsService.shared.trackAudioPlayback(
                audioId: audio.id,
                audioTitle: audio.title,
                action: .seeked,
                metadata: [
                    "from_position": currentTime,
                    "to_position": time,
                    "seek_distance": abs(time - currentTime),
                    "category": audio.tag ?? "unknown"
                ]
            )
        }
        
        player.seek(to: targetTime)
    }

    func repeatTrack() {
        onRepeat.toggle()
    }

    func changePlaybackSpeed(to speed: Float) {
        playbackSpeed = speed
        // Only set rate if player is actually playing
        // Setting rate when not playing can interfere with playback
        if isPlaying, let player = player {
            player.rate = speed
        }
    }

    func resetPlayer() {
        // Safely remove KVO observer
        if player?.currentItem != nil {
            do {
                player?.currentItem?.removeObserver(self, forKeyPath: "status")
            }
        }
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        currentTime = 0
        isPlaying = false
        print("🟣 resetPlayer COMPLETED - isPlaying now false")
        
        // Ensure we stop the background music player to prevent conflicts
        AudioPlayerService.shared.stopMusic()
        print("🟣 resetPlayer fully completed")
    }

//    func addToQueue(item: AudioDeclaration) {
//        audioQueue.append(item)
//        print("\(item), added to queu RWRW")
//    }

    func clearQueue() {
        audioQueue.removeAll()
        urlQueue.removeAll()
    }

//    func addToQueue(_ item: URL?) {
//        guard let item = item else { return }
//        urlQueue.append(item)
//        print("\(item), added to queue")
//    }
//    func insert(_ item: URL?) {
//        guard let item = item else { return }
//        urlQueue.insert(item, at: 0)
//        print("\(item), inserted to queue")
//    }

    private func updateNowPlayingInfo() {
        guard let player = player,
              let currentItem = player.currentItem else { return }

        let currentTime = CMTimeGetSeconds(player.currentTime())
        let duration = CMTimeGetSeconds(currentItem.asset.duration)

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrack,
            MPMediaItemPropertyArtist: subtitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let image = UIImage(named: imageUrl) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.isPlaying = true
            self?.updateNowPlayingInfo()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.isPlaying = false
            self?.updateNowPlayingInfo()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let seekEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: seekEvent.positionTime)
            return .success
        }
    }
    
    // KVO observer for player status
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ Player is ready to play")
                case .failed:
                    if let error = playerItem.error as NSError? {
                        #if targetEnvironment(simulator)
                        print("⚠️ Simulator Audio Error (code \(error.code))")
                        print("   This is a known simulator limitation that doesn't affect physical devices.")
                        print("   Audio works perfectly on real devices.")
                        
                        if error.code == -11800 {
                            print("\n   🔧 Simulator Workarounds:")
                            print("   1. Try playing the audio again (sometimes works on 2nd attempt)")
                            print("   2. Reset simulator: Device → Erase All Content and Settings")
                            print("   3. Quit and restart the simulator")
                            print("   4. Test on a physical device for accurate behavior")
                            print("\n   ✅ Note: Audio playback works perfectly on physical devices")
                        }
                        #else
                        print("❌ Player failed with error code \(error.code): \(error.localizedDescription)")
                        print("   Error domain: \(error.domain)")
                        print("   Error info: \(error.userInfo)")
                        #endif
                    } else {
                        print("❌ Player failed with unknown error")
                    }
                case .unknown:
                    print("⚠️ Player status unknown")
                @unknown default:
                    print("⚠️ Player status unhandled")
                }
            }
        }
    }
}
