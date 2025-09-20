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
        // Ensure audio session remains active
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Failed to keep audio session active
        }
        
        // Force the player to continue if it was playing
        if isPlaying, let player = player {
            player.play()
        }
        
        // Update the Now Playing info
        updateNowPlayingInfo()
    }
    
    @objc private func handleAppWillEnterForeground() {
        // If audio should be playing but isn't, resume it
        if isPlaying && player?.rate == 0 {
            player?.play()
        }
        
        // Update Now Playing info when returning
        updateNowPlayingInfo()
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

//    func startMonitoringPlayback() {
////        if let token = timeObserverToken {
////            timeObserverToken = nil
////        }
//        print("start monitioring RWRW")
//        let interval = CMTime(seconds: 5.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
//        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
//            print("check RWRW")
//            self?.checkIfShouldPrefetch(time: time)
//           
//        }
//    }

//    func checkIfShouldPrefetch(time: CMTime) {
//        print(autoPlayAudio, !audioQueue.isEmpty, !hasPrefetchedNext, "RWRW yee")
//        guard autoPlayAudio, !audioQueue.isEmpty, !hasPrefetchedNext else { return }
//        guard let duration = player?.currentItem?.duration.seconds, duration.isFinite else { return }
//
//        let currentTime = time.seconds
//        let remainingTime = duration - currentTime
//
//        if remainingTime <= 60 {
//            hasPrefetchedNext = true
//            prefetchNextAudio()
//        }
//    }

//    func playNextInQueue() {
//        guard !urlQueue.isEmpty else {
//            print("Queue is empty RWRW")
//            return
//        }
//
//        let next = audioQueue.removeFirst()
//        let nextURL = urlQueue.removeFirst()
//
//        print("Now playing next queued track: \(next.title) RWRW")
//
//        isBarVisible = false
//        loadAudio(from: nextURL, isSameItem: false)
//
//        currentTrack = next.title
//        subtitle = next.subtitle
//        imageUrl = next.imageUrl
//        selectedItem = next
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
//            withAnimation(.easeOut(duration: 0.4)) {
//                self.isBarVisible = true
//            }
//        }
//    }

//    func prefetchNextAudio() {
//        guard let next = audioQueue.first else { return }
//        print("prefetching next audio RWRW")
//        audioDeclarationViewModel?.fetchAudio(for: next) { [weak self] result in
//            DispatchQueue.main.async {
//                guard let self = self else { return }
//                switch result {
//                case .success(let url):
//                   // if !self.urlQueue.isEmpty {
//                        self.addToQueue(url)
//                        print("adding to queue RWRW")
//                   // }
//                case .failure(let error):
//                    print("Failed to prefetch: \(error.localizedDescription)")
//                }
//            }
//        }
//    }

    func loadAudio(from url: URL, isSameItem: Bool) {
        hasPrefetchedNext = false
       // startMonitoringPlayback()
        

        if isSameItem { 
            // If same item and not playing, start playing
            if !isPlaying {
                player?.play()
                isPlaying = true
            }
            return 
        }
        resetPlayer()

        // Improved audio session setup with error handling for background playback
        do {
            // Configure for background audio playback
            let audioSession = AVAudioSession.sharedInstance()
            #if targetEnvironment(simulator)
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            #else
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            #endif
            try audioSession.setActive(true)
            // Audio session configured successfully
        } catch {
            // Failed to configure audio session
        }

        // Verify file exists at URL (important for simulator)
        if !FileManager.default.fileExists(atPath: url.path) {
            // WARNING: Audio file does not exist
            return
        }
        
        player = AVPlayer(url: url)
        
        // Add observer for player status
        player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        
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
            }
            self.updateNowPlayingInfo()
        }
        // Always start playing when loading audio
        if let player = player {
            player.play()
        }
        isPlaying = true
        
        
        // Track listen event for metrics
        if let currentAudio = selectedItem {
            ListenerMetricsService.shared.trackListen(
                contentId: currentAudio.id,
                contentType: .audio
            )
        }
        AudioPlayerService.shared.pauseMusic()
        updateNowPlayingInfo()

        
       
    }

    func togglePlayPause() {
        guard let player = player else { 
            return 
        }

        
        if isPlaying {
            player.pause()
            AudioPlayerService.shared.playMusic()
        } else {
            AudioPlayerService.shared.pauseMusic()
            player.play()
        }
        isPlaying.toggle()
        
        updateNowPlayingInfo()
    }

    func seek(to time: Double) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: time, preferredTimescale: 1)
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
        print("🟣 resetPlayer START - current isPlaying: \(isPlaying)")
        // Safely remove KVO observer
        if player?.currentItem != nil {
            do {
                player?.currentItem?.removeObserver(self, forKeyPath: "status")
            } catch {
                // Observer wasn't added or already removed
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
                    print("Player is ready to play")
                case .failed:
                    print("Player failed with error: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                case .unknown:
                    print("Player status unknown")
                @unknown default:
                    print("Player status unhandled")
                }
            }
        }
    }
}
