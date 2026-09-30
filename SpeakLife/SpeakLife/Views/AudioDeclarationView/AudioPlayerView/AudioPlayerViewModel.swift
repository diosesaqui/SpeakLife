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
    
    // Progress tracking properties
    private var playbackStartTime: Date?
    private var totalListenTime: TimeInterval = 0
    private var lastProgressUpdate: TimeInterval = 0
    private var progressThresholds = [10, 20, 25, 50, 75, 85, 90, 100] // Percentage thresholds to track
    private var reportedThresholds = Set<Int>() // Track which thresholds were already reported
    
    @Published var isPlaying: Bool = false {
        didSet {
            // Update the static property
            AudioPlayerViewModel.hasActiveAudio = isPlaying
            
            // Track playback time
            if isPlaying {
                playbackStartTime = Date()
            } else if let startTime = playbackStartTime {
                totalListenTime += Date().timeIntervalSince(startTime)
                playbackStartTime = nil
            }
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
    /// The episode loaded in the player. Stays set while the player sheet is
    /// closed and the bar is showing; only `stop()` clears it. It used to be
    /// the sheet's `item:` binding, so dismissing the sheet nil'd it and every
    /// progress, completion and "played" update was silently dropped for
    /// anyone listening from the bar.
    @Published var selectedItem: AudioDeclaration? = nil
    /// Whether the full player sheet is up. Separate from `selectedItem` so
    /// the queue can change tracks without SwiftUI tearing the sheet down and
    /// re-presenting it for the new item.
    @Published var isPlayerPresented: Bool = false

    // MARK: Up Next queue

    enum PlaySource: String {
        /// The listener tapped an episode.
        case tap
        /// The previous episode finished and the queue advanced.
        case queue
        /// The listener pressed next, in the app or on the lock screen.
        case skip
        /// The listener tapped an episode inside the Up Next list.
        case picked
    }

    @Published private(set) var queue = UpNextQueue()
    /// The episode being downloaded to play next, if any. Drives the loading
    /// state and blocks the same episode being queued behind itself.
    @Published private(set) var loadingItemId: String?
    /// A one-off message for the UI (e.g. the next episode failed to load
    /// while the app was in the background). The view clears it once shown.
    @Published var queueNotice: String?
    /// The current episode reached its end and nothing followed it.
    @Published private(set) var playbackEnded = false

    /// Resolves an episode to a local file, downloading it when needed. Set
    /// by the screen that owns the catalog, because the queue has to fetch
    /// the next episode on its own when the current one ends, often with the
    /// app in the background and no view around to do it.
    var trackResolver: ((AudioDeclaration, @escaping (Result<URL, Error>) -> Void) -> Void)?
    /// Checked when the queue advances, not only when an episode is queued:
    /// a subscription can lapse while premium episodes wait in line.
    var canPlay: (AudioDeclaration) -> Bool = { _ in true }

    /// Bumped by every load request. A download that finishes after a newer
    /// request was made is stale and must not replace what the listener
    /// picked since.
    private var loadGeneration = 0
    private var currentSource: PlaySource = .tap
    private var latestRequestSource: PlaySource = .tap
    private var prefetchedId: String?
    /// Identifies the newest `loadAudio` call. Asset validation finishes
    /// asynchronously, so an older call's callback must not build a player
    /// over a newer one's.
    private var assetLoadID = UUID()
    /// Keeps the app alive from the moment a queue advance starts until the
    /// next episode is actually playing, not just until its file is ready.
    private var advanceBackgroundTask: BackgroundTaskToken?
    /// Longest episode finished in this listening session. The completion
    /// paywall fires once, when the session ends, judged on this rather than
    /// on whichever episode happened to be last.
    private var longestCompletedDuration: Double = 0
    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
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
        
        // Only maintain audio session if content is actively playing, or the
        // queue is between episodes and about to start the next one.
        if (isPlaying && player?.rate ?? 0 > 0) || loadingItemId != nil {
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
                    togglePlayPause() // This will pause the audio properly
                }
                backgroundTime = nil
                return
            }
        }
        
        // Only resume if content audio was actively playing and we weren't suspended too long
        if isPlaying && player?.rate == 0 && AudioPlayerViewModel.hasActiveAudio {
            // This is content audio that should resume at current playback speed
            player?.rate = playbackSpeed
            updateNowPlayingInfo()
        }
        
        // Always ensure background music is stopped
        AudioPlayerService.shared.stopMusic()
        
        backgroundTime = nil
    }

    deinit {
        // The command center is shared; leave no targets pointing at a
        // player that no longer exists.
        for (command, target) in remoteCommandTargets {
            command.removeTarget(target)
        }
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


    /// - Parameter item: the episode `url` belongs to. It becomes
    ///   `selectedItem` after the previous episode's final stats are reported
    ///   and before the new episode's `started` event, so neither is
    ///   attributed to the wrong episode. Pass nil to keep `selectedItem`.
    func loadAudio(from url: URL, isSameItem: Bool, item: AudioDeclaration? = nil) {
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

        if let item = item {
            selectedItem = item
            currentTrack = item.title
            subtitle = item.subtitle
            imageUrl = item.imageUrl
            // The old episode's length would otherwise drive the slider and
            // the progress milestones until the new asset reports its own.
            duration = 0
        }
        playbackEnded = false
        
        // Reset progress tracking for new audio
        totalListenTime = 0
        playbackStartTime = nil
        reportedThresholds.removeAll()
        
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
            handleLoadFailure()
            return
        }
        
        // Check file size to ensure it's not empty
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int ?? 0
            if fileSize == 0 {
                print("❌ Audio file is empty")
                try? FileManager.default.removeItem(at: url)
                handleLoadFailure()
                return
            }
        } catch {
            print("❌ Failed to check file attributes: \(error)")
        }
        
        // For simulator, skip complex asset validation that causes -11800 errors
        #if targetEnvironment(simulator)
        // Simulator: Just create the player directly
        
        // Ensure the URL is properly formatted for simulator
        let fileURL: URL
        if url.isFileURL {
            fileURL = url
        } else {
            fileURL = URL(fileURLWithPath: url.path)
        }
        
        self.createAndConfigurePlayer(with: fileURL)
        #else
        // Physical device: Full validation
        let asset = AVAsset(url: url)
        let loadID = UUID()
        assetLoadID = loadID
        
        // Load the asset's tracks asynchronously to check if it's valid
        asset.loadValuesAsynchronously(forKeys: ["playable", "tracks"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // A newer episode was loaded while this one validated.
                guard self.assetLoadID == loadID else { return }
                
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
            
            // Check and report listening progress
            self.checkAndReportListeningProgress()
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
                // Mark as played even when repeating — user listened to completion
                if let audio = self.selectedItem {
                    AudioProgressStore.shared.markPlayed(audio.id)
                }
                self.player?.seek(to: .zero)
                // Resume at current playback speed
                self.player?.rate = self.playbackSpeed
            } else {
                self.isPlaying = false

                // Up Next: move straight on. The audio session stays active
                // so iOS keeps the app running in the background between
                // episodes. The completion paywall waits for the end of the
                // session rather than cutting into the middle of it. No
                // rewind first: the finished episode's final stats are
                // reported when the next one loads, and they should read
                // "completed", not "bounced at 0%".
                if let duration = self.player?.currentItem?.duration {
                    let durationInSeconds = CMTimeGetSeconds(duration)
                    if !duration.isIndefinite && durationInSeconds > 0 {
                        self.longestCompletedDuration = max(self.longestCompletedDuration, durationInSeconds)
                    }
                }

                if !self.playNextInQueue(source: .queue) {
                    self.playbackEnded = true
                    self.player?.seek(to: .zero)

                    // Track audio completion for paywall trigger (4+ minute
                    // audio), once per session, on its longest episode.
                    if self.longestCompletedDuration > 0 {
                        PaywallTriggerManager.shared.trackAudioCompletion(durationInSeconds: self.longestCompletedDuration)
                        self.longestCompletedDuration = 0
                    }

                    self.deactivateSessionIfBackgrounded()
                }
            }
            self.updateNowPlayingInfo()
        }
        // Start playing when loading audio
        #if targetEnvironment(simulator)
        // Simulator: Delay play to allow player to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.player?.play()
            // Keep the listener's speed when the queue moves to the next
            // episode; play() alone would drop back to 1x under a 1.5x label.
            if self.playbackSpeed != 1.0 { self.player?.rate = self.playbackSpeed }
            self.isPlaying = true
        }
        #else
        // Physical device: Play immediately
        if let player = player {
            player.play()
            // Keep the listener's speed when the queue moves to the next
            // episode; play() alone would drop back to 1x under a 1.5x label.
            if playbackSpeed != 1.0 { player.rate = playbackSpeed }
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
                    "repeat_enabled": onRepeat,
                    "source": currentSource.rawValue,
                    "queue_length": queue.count
                ]
            )
        }
        prefetchNextIfNeeded()
        updateRemoteQueueCommands()
        // Audio is going again, which is what keeps a background app alive.
        advanceBackgroundTask?.end()
        advanceBackgroundTask = nil

        
        
        // Track listen event for metrics
      
        // Background music already stopped earlier in setup process
        updateNowPlayingInfo()

        
       
    }

    func togglePlayPause() {
        // The last episode ended and something is still queued (the next one
        // failed to load, most likely offline). Play means "try the queue
        // again", not "replay what just finished".
        if !isPlaying, playbackEnded, !queue.isEmpty {
            _ = playNextInQueue(source: .skip)
            return
        }
        // Between episodes the old one sits at its end while the next
        // downloads. Resuming it would end it again at once and pop a second
        // episode off the queue.
        if !isPlaying, loadingItemId != nil {
            return
        }
        guard let player = player else { 
            // The episode never got a working player (its file failed to
            // load). Play means fetch it again; a bad file was deleted, so
            // this re-downloads it.
            if let item = selectedItem {
                play(item, source: .tap)
            }
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
            // Use rate instead of play() so the current playback speed is preserved
            player.rate = playbackSpeed
            // Replaying a finished episode makes it the current one again, so
            // new queue picks wait behind it instead of cutting it off.
            playbackEnded = false
        }
        isPlaying.toggle()
        
        updateNowPlayingInfo()
    }
    
    private func handleCorruptedAudioFile(item: AudioDeclaration, url: URL) {
        
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
            guard let self = self else { return }
            self.isPlaying = false
            // Warning: 
            print("⚠️ Audio file was corrupted. Please try playing it again to re-download.")
            // The file was deleted above, so a retry re-downloads it.
            self.handleLoadFailure()
        }
    }

    func seek(to time: Double) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: time, preferredTimescale: 1)
        
        // Track seek event with progress information
        if let audio = selectedItem, duration > 0 {
            let fromPercentage = Int((currentTime / duration) * 100)
            let toPercentage = Int((time / duration) * 100)
            
            AnalyticsService.shared.trackAudioPlayback(
                audioId: audio.id,
                audioTitle: audio.title,
                action: .seeked,
                metadata: [
                    "from_position": currentTime,
                    "to_position": time,
                    "from_percentage": fromPercentage,
                    "to_percentage": toPercentage,
                    "seek_direction": time > currentTime ? "forward" : "backward",
                    "seek_distance": abs(time - currentTime),
                    "category": audio.tag ?? "unknown"
                ]
            )
        }
        
        player.seek(to: targetTime)
        // Seeking back into a finished episode makes it the one to resume.
        if time < duration { playbackEnded = false }
    }

    func repeatTrack() {
        onRepeat.toggle()
        
        // Track repeat toggle
        if let audio = selectedItem {
            AnalyticsService.shared.trackUserAction(
                "repeat_toggled",
                category: "audio",
                metadata: [
                    "audio_id": audio.id,
                    "audio_title": audio.title,
                    "repeat_enabled": onRepeat,
                    "playback_position": currentTime,
                    "progress_percentage": duration > 0 ? Int((currentTime / duration) * 100) : 0
                ]
            )
        }
    }

    func changePlaybackSpeed(to speed: Float) {
        let previousSpeed = playbackSpeed
        playbackSpeed = speed
        
        // Track speed change
        if let audio = selectedItem {
            AnalyticsService.shared.trackUserAction(
                "playback_speed_changed",
                category: "audio",
                metadata: [
                    "audio_id": audio.id,
                    "audio_title": audio.title,
                    "previous_speed": previousSpeed,
                    "new_speed": speed,
                    "playback_position": currentTime,
                    "progress_percentage": duration > 0 ? Int((currentTime / duration) * 100) : 0
                ]
            )
        }
        
        // Only set rate if player is actually playing
        // Setting rate when not playing can interfere with playback
        if isPlaying, let player = player {
            player.rate = speed
        }
    }

    private func checkAndReportListeningProgress() {
        guard duration > 0 else { return }
        
        let progressPercentage = Int((currentTime / duration) * 100)
        
        // Check each threshold
        for threshold in progressThresholds {
            if progressPercentage >= threshold && !reportedThresholds.contains(threshold) {
                reportedThresholds.insert(threshold)
                
                // Track the progress milestone
                if let audio = selectedItem {
                    let actualListenTime = totalListenTime + (playbackStartTime != nil ? Date().timeIntervalSince(playbackStartTime!) : 0)
                    
                    AnalyticsService.shared.trackAudioPlayback(
                        audioId: audio.id,
                        audioTitle: audio.title,
                        action: .progressMilestone,
                        metadata: [
                            "progress_percentage": threshold,
                            "actual_time_listened": actualListenTime,
                            "audio_duration": duration,
                            "playback_position": currentTime,
                            "category": audio.tag ?? "unknown",
                            "is_premium": audio.isPremium,
                            "playback_speed": playbackSpeed
                        ]
                    )

                    // Persist as "played" once the listener passes the 85% mark
                    if threshold >= 85 {
                        AudioProgressStore.shared.markPlayed(audio.id)

                        // Credit the checklist's listen row.
                        //
                        // `StreakIntegrationManager` has always listened for
                        // this, but nothing ever posted it: step 2 of the
                        // integration instructions in that file ("In AudioPlayer
                        // or audio playback completion") was the one of the four
                        // that never got wired. The other three did, which is why
                        // `read_devotional` completed for 412 people over 30 days
                        // while `listen_audio` — unlocked for the same 558 —
                        // completed for 157, and every one of those was someone
                        // ticking the box by hand.
                        //
                        // Fires at 85% rather than at end-of-item because that is
                        // already this app's bar for "played", right above. A
                        // 20-minute track abandoned at 90% was still listened to.
                        //
                        // Idempotent: `completeTask` ignores an id that is
                        // already done, so replays and repeats cost nothing.
                        StreakIntegrationManager.notifyAudioCompleted()
                    }

                    print("📊 Audio Progress: \(threshold)% reached for \"\(audio.title)\"")
                    print("   Listen time: \(String(format: "%.1f", actualListenTime))s of \(String(format: "%.1f", duration))s")
                }
            }
        }
    }
    
    private func reportFinalListeningStats() {
        // No player means these stats were already reported for this episode.
        guard player != nil, let audio = selectedItem, duration > 0 else { return }
        
        let finalListenTime = totalListenTime + (playbackStartTime != nil ? Date().timeIntervalSince(playbackStartTime!) : 0)
        let finalProgressPercentage = Int((currentTime / duration) * 100)
        
        // Determine engagement level based on percentage listened
        let engagementLevel: String
        if finalProgressPercentage >= 90 {
            engagementLevel = "completed"
        } else if finalProgressPercentage >= 50 {
            engagementLevel = "engaged"
        } else if finalProgressPercentage >= 25 {
            engagementLevel = "partially_engaged"
        } else if finalProgressPercentage >= 10 {
            engagementLevel = "sampled"
        } else {
            engagementLevel = "bounced"
        }
        
        AnalyticsService.shared.trackAudioPlayback(
            audioId: audio.id,
            audioTitle: audio.title,
            action: .stopped,
            metadata: [
                "final_progress_percentage": finalProgressPercentage,
                "total_listen_time": finalListenTime,
                "audio_duration": duration,
                "engagement_level": engagementLevel,
                "category": audio.tag ?? "unknown",
                "is_premium": audio.isPremium,
                "playback_speed": playbackSpeed,
                "was_repeated": onRepeat,
                "highest_milestone_reached": reportedThresholds.max() ?? 0
            ]
        )
        
        print("📈 Final Audio Stats for \"\(audio.title)\":")
        print("   Progress: \(finalProgressPercentage)% (\(engagementLevel))")
        print("   Total listen time: \(String(format: "%.1f", finalListenTime))s")
        print("   Milestones reached: \(reportedThresholds.sorted())")
    }

    func resetPlayer() {
        // Report final stats before resetting
        reportFinalListeningStats()
        
        // Reset tracking variables
        totalListenTime = 0
        playbackStartTime = nil
        reportedThresholds.removeAll()
        
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
        
        // Ensure we stop the background music player to prevent conflicts
        AudioPlayerService.shared.stopMusic()
    }

    // MARK: - Playback requests

    /// Downloads `item` if needed and plays it. Every play goes through here,
    /// tap or queue, so the newest request always wins: a slow download that
    /// lands after the listener picked something else is dropped and its
    /// completion gets a `CancellationError`.
    func play(_ item: AudioDeclaration,
              source: PlaySource,
              completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let resolver = trackResolver else {
            completion?(.failure(UpNextError.noResolver))
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        loadingItemId = item.id
        latestRequestSource = source

        resolver(item) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard generation == self.loadGeneration else {
                    completion?(.failure(CancellationError()))
                    return
                }
                self.loadingItemId = nil
                switch result {
                case .success(let url):
                    // Picking an episode that was waiting in line plays it
                    // now; leaving it queued would play it a second time.
                    if self.queue.contains(item.id) {
                        self.mutateQueue { $0.remove(id: item.id) }
                    }
                    if self.prefetchedId == item.id { self.prefetchedId = nil }
                    self.currentSource = source
                    // Same episode only counts if it still has a player; after
                    // a failed load it has to be built again.
                    let isSameItem = self.selectedItem?.id == item.id && self.player != nil
                    self.loadAudio(from: url, isSameItem: isSameItem, item: item)
                    self.isBarVisible = true
                    completion?(.success(()))
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }
    }

    /// Ends the listening session: stops playback, drops the queue and any
    /// download in flight, and clears the lock screen.
    func stop() {
        loadGeneration += 1
        loadingItemId = nil
        resetPlayer()
        mutateQueue { $0.removeAll() }
        prefetchedId = nil
        playbackEnded = false
        longestCompletedDuration = 0
        advanceBackgroundTask?.end()
        advanceBackgroundTask = nil
        selectedItem = nil
        isPlayerPresented = false
        isBarVisible = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Up Next queue

    /// True while there is an episode the queue should wait behind: one is
    /// loaded and not finished, or one is downloading. When false, queueing
    /// an episode should simply play it.
    var hasActiveSession: Bool {
        loadingItemId != nil || (selectedItem != nil && !playbackEnded)
    }

    @discardableResult
    func enqueue(_ item: AudioDeclaration, placement: UpNextQueue.Placement) -> UpNextQueue.AddResult {
        // The episode downloading right now is about to be "now playing".
        if item.id == loadingItemId { return .isNowPlaying }
        var result = UpNextQueue.AddResult.full
        mutateQueue { result = $0.add(item, placement: placement, nowPlayingId: self.selectedItem?.id) }

        AnalyticsService.shared.trackUserAction(
            "audio_queue_added",
            category: "audio",
            metadata: [
                "audio_id": item.id,
                "audio_title": item.title,
                // Not "category": trackUserAction's own category ("audio")
                // would be overwritten by the merge.
                "audio_category": item.tag ?? "unknown",
                "placement": placement.rawValue,
                "result": Self.analyticsLabel(for: result),
                "queue_length": queue.count
            ]
        )
        return result
    }

    func removeFromQueue(atOffsets offsets: IndexSet) {
        let removed = offsets.compactMap { queue.items.indices.contains($0) ? queue.items[$0] : nil }
        mutateQueue { $0.remove(atOffsets: offsets) }
        for item in removed {
            AnalyticsService.shared.trackUserAction(
                "audio_queue_removed",
                category: "audio",
                metadata: ["audio_id": item.id, "queue_length": queue.count]
            )
        }
    }

    func removeFromQueue(id: String) {
        guard let index = queue.position(of: id) else { return }
        removeFromQueue(atOffsets: IndexSet(integer: index))
    }

    func moveInQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        mutateQueue { $0.move(fromOffsets: source, toOffset: destination) }
    }

    func clearQueue() {
        guard !queue.isEmpty else { return }
        let cleared = queue.count
        mutateQueue { $0.removeAll() }
        AnalyticsService.shared.trackUserAction(
            "audio_queue_cleared",
            category: "audio",
            metadata: ["cleared_count": cleared]
        )
    }

    /// Skips the rest of the current episode. The current one keeps playing
    /// until the next is ready, so a slow download never leaves silence.
    func skipToNext() {
        guard !queue.isEmpty else { return }
        if let audio = selectedItem {
            AnalyticsService.shared.trackUserAction(
                "audio_queue_skipped",
                category: "audio",
                metadata: [
                    "audio_id": audio.id,
                    "audio_title": audio.title,
                    "progress_percentage": duration > 0 ? Int((currentTime / duration) * 100) : 0,
                    "queue_length": queue.count
                ]
            )
        }
        _ = playNextInQueue(source: .skip)
    }

    /// Jumps straight to a queued episode. Everything else stays queued.
    func playFromQueue(_ item: AudioDeclaration) {
        guard canPlay(item) else {
            mutateQueue { $0.remove(id: item.id) }
            return
        }
        play(item, source: .picked) { [weak self] result in
            guard case .failure(let error) = result, !(error is CancellationError) else { return }
            self?.queueNotice = "Couldn't load \"\(item.title)\". Check your connection and try again."
        }
    }

    /// Starts the next playable queued episode. Returns false when there is
    /// nothing left to play, so the caller can wind the session down.
    @discardableResult
    private func playNextInQueue(source: PlaySource) -> Bool {
        var popped: (next: AudioDeclaration?, skipped: [AudioDeclaration]) = (nil, [])
        mutateQueue { popped = $0.popNext(where: self.canPlay) }

        for locked in popped.skipped {
            AnalyticsService.shared.trackUserAction(
                "audio_queue_item_dropped",
                category: "audio",
                metadata: ["audio_id": locked.id, "reason": "locked"]
            )
        }
        guard let next = popped.next else { return false }

        // Between episodes nothing is playing, and iOS may suspend a
        // background app with no audio going. Ask for time to finish the
        // download; a prefetched episode needs none of it.
        // Held until the next episode is actually playing (ended in
        // createAndConfigurePlayer), not just until its file is on disk.
        advanceBackgroundTask?.end()
        let backgroundTask = BackgroundTaskToken(name: "AudioQueueAdvance")
        advanceBackgroundTask = backgroundTask

        play(next, source: source) { [weak self] result in
            guard let self = self else {
                backgroundTask.end()
                return
            }
            if case .failure = result {
                backgroundTask.end()
                if self.advanceBackgroundTask === backgroundTask { self.advanceBackgroundTask = nil }
            }

            switch result {
            case .success:
                AnalyticsService.shared.trackUserAction(
                    "audio_queue_advanced",
                    category: "audio",
                    metadata: [
                        "audio_id": next.id,
                        "audio_title": next.title,
                        "source": source.rawValue,
                        "queue_length": self.queue.count
                    ]
                )
            case .failure(let error) where error is CancellationError:
                // Overtaken by a newer request. If the listener picked
                // something else, this episode was never heard, so it goes
                // back to the front of the line. A second press of next is
                // different: it means "not this one either".
                if self.latestRequestSource != .skip, self.hasActiveSession {
                    self.mutateQueue { _ = $0.add(next, placement: .next, nowPlayingId: self.selectedItem?.id) }
                }
            case .failure:
                // Most likely offline. Put the episode back and stop rather
                // than burning through the whole queue one failure at a time.
                // Play (or next) tries again.
                self.mutateQueue { _ = $0.add(next, placement: .next, nowPlayingId: self.selectedItem?.id) }
                if !self.isPlaying {
                    self.playbackEnded = true
                    self.player?.seek(to: .zero)
                    self.deactivateSessionIfBackgrounded()
                }
                self.queueNotice = "Couldn't load \"\(next.title)\". Check your connection and press play to try again."
                AnalyticsService.shared.trackUserAction(
                    "audio_queue_item_dropped",
                    category: "audio",
                    metadata: ["audio_id": next.id, "reason": "load_failed"]
                )
            }
        }
        return true
    }

    /// Every queue change goes through here so the lock screen's next
    /// button and the prefetch stay in step with the list.
    private func mutateQueue(_ change: (inout UpNextQueue) -> Void) {
        change(&queue)
        updateRemoteQueueCommands()
        prefetchNextIfNeeded()
    }

    /// Downloads the head of the queue while the current episode plays, so
    /// the switch is instant and does not depend on the network, or on iOS
    /// letting a silent background app finish a download. Only the next
    /// episode, never the whole queue, to keep cellular use proportionate.
    private func prefetchNextIfNeeded() {
        guard selectedItem != nil,
              let next = queue.next,
              next.id != prefetchedId,
              canPlay(next),
              let resolver = trackResolver else { return }
        prefetchedId = next.id
        resolver(next) { [weak self] result in
            guard case .failure = result else { return }
            DispatchQueue.main.async {
                // Let a later prefetch try again.
                if self?.prefetchedId == next.id { self?.prefetchedId = nil }
            }
        }
    }

    /// An episode's file turned out missing, empty or unplayable after
    /// `play()` had already handed it over. Leave no half-loaded session
    /// behind: a queued session moves on, and otherwise the session counts
    /// as ended, so Play retries and new queue picks play straight away.
    private func handleLoadFailure() {
        isPlaying = false
        if currentSource != .tap, playNextInQueue(source: .queue) {
            return
        }
        if let item = selectedItem {
            queueNotice = "Couldn't play \"\(item.title)\". Press play to try again."
        }
        playbackEnded = true
        advanceBackgroundTask?.end()
        advanceBackgroundTask = nil
        deactivateSessionIfBackgrounded()
    }

    /// If audio finished while app is in background, deactivate audio session.
    /// This prevents zombie audio sessions that could allow random playback.
    private func deactivateSessionIfBackgrounded() {
        guard UIApplication.shared.applicationState != .active else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to deactivate audio session after content finished: \(error)")
        }
    }

    private static func analyticsLabel(for result: UpNextQueue.AddResult) -> String {
        switch result {
        case .added: return "added"
        case .moved: return "moved"
        case .alreadyQueued: return "already_queued"
        case .isNowPlaying: return "now_playing"
        case .notPlayable: return "not_playable"
        case .full: return "full"
        }
    }


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
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackSpeed) : 0.0
        ]

        if let image = UIImage(named: imageUrl) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play and pause go through togglePlayPause so the lock screen gets
        // the same rules as the in-app button: retry a stalled queue, ignore
        // play in the gap between episodes, keep the playback speed.
        let playTarget = commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying { self.togglePlayPause() }
            return .success
        }

        let pauseTarget = commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying { self.togglePlayPause() }
            return .success
        }

        let seekTarget = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let seekEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: seekEvent.positionTime)
            return .success
        }

        let nextTarget = commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self, !self.queue.isEmpty, self.loadingItemId == nil else { return .noSuchContent }
            self.skipToNext()
            return .success
        }
        remoteCommandTargets = [
            (commandCenter.playCommand, playTarget),
            (commandCenter.pauseCommand, pauseTarget),
            (commandCenter.changePlaybackPositionCommand, seekTarget),
            (commandCenter.nextTrackCommand, nextTarget)
        ]
        // There is no history to go back through, so the lock screen should
        // not offer a previous button that does nothing.
        commandCenter.previousTrackCommand.isEnabled = false
        // Next-track availability is set by whichever player is actually
        // playing (see updateRemoteQueueCommands), not at init, so an idle
        // second player can't switch it off for the active one.
    }

    private func updateRemoteQueueCommands() {
        // Only the player with something loaded owns the lock screen.
        guard selectedItem != nil || loadingItemId != nil else { return }
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = !queue.isEmpty
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
                        // Warning: 
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
                    // Warning: 
                    print("⚠️ Player status unknown")
                @unknown default:
                    // Warning: 
                    print("⚠️ Player status unhandled")
                }
            }
        }
    }
}

enum UpNextError: LocalizedError {
    case noResolver

    var errorDescription: String? {
        "Audio isn't ready yet. Please try again in a moment."
    }
}

/// One `beginBackgroundTask` per queue advance, ended exactly once: when the
/// load settles or when iOS says time is up, whichever comes first.
private final class BackgroundTaskToken {
    private var id: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
