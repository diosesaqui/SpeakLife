//
//  VoicePresenceService.swift
//  SpeakLife
//
//  Listens while the user speaks the counter-declaration. It measures ONE
//  thing: was there a voice.
//
//  **No transcription. Not now, not later.** The app must never tell someone
//  they said the declaration wrong — that turns a moment of faith into a test
//  they can fail, and a failed test mid-storm reads as condemnation. Presence of
//  voice is sufficient, and the confirmation is visual: the waveform fills, then
//  settles. Nothing is graded, nothing is scored, nothing is kept.
//
//  Recording uses `AVAudioRecorder` metering rather than `AVAudioEngine` +
//  `installTap`. The spec called for AVAudioEngine, but this codebase removed
//  installTap deliberately: it raises an uncatchable NSException
//  (AUGraphNodeBaseV3::CreateRecordingTap) on some devices and OS versions. See
//  the header of `VoiceInputManager.swift`. Metering gives the same amplitude
//  stream the waveform needs, with none of that risk.
//
//  Nothing is written that outlives the screen: audio goes to a single temp file
//  which is deleted on stop. There is no upload, no retention, no analysis.
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class VoicePresenceService: NSObject, ObservableObject {

    /// Rolling amplitude, 0...1, newest last. Drives the waveform.
    @Published private(set) var levels: [Float] = []
    /// True once a voice has been heard for `sustainedVoiceSeconds`. The only
    /// verdict this service produces.
    @Published private(set) var heardVoice = false
    @Published private(set) var isListening = false
    /// Set when the mic was refused. The view swaps in the press-and-hold
    /// fallback and never asks again.
    @Published private(set) var permissionDenied = false
    /// The mic was armed for the full window and heard nothing.
    ///
    /// Without a terminal state the screen sat on "Listening…" while nothing was
    /// listening, with no way forward — someone whose mic is muted by a case, or
    /// who got interrupted, was simply stuck. The view swaps to press-and-hold
    /// when this flips.
    @Published private(set) var timedOutWithoutVoice = false

    /// The hard floor. Nothing quieter than this counts as speech, whatever the
    /// room sounds like.
    ///
    /// Levels map as `(dBFS + 50) / 50`, so this is roughly −39 dBFS. The
    /// original 0.18 was −41 dBFS — ordinary room ambience — and the drill
    /// completed itself on an empty room.
    private let minimumVoiceThreshold: Float = 0.22
    /// How far above the room's own noise floor a sound has to rise.
    ///
    /// A fixed threshold is wrong in both directions: too low in a kitchen, too
    /// high for someone speaking under their breath beside a sleeping child.
    /// Measuring the room during the reading grace and then asking for a clear
    /// step above it adapts to both, which is the difference between hearing a
    /// whisper and hearing a refrigerator.
    private let voiceMarginOverAmbient: Float = 0.16
    /// How long a voice has to be present before it counts.
    ///
    /// The shortest counter in the bank is nine words, which takes about three
    /// seconds to say. 0.8s was short enough that a cough or a passing car
    /// finished the rep for you.
    private let sustainedVoiceSeconds: TimeInterval = 1.2
    /// Voice heard before this much time has passed does not count.
    ///
    /// You cannot speak a line you have not read yet. Without this, the mic is
    /// live while the declaration is still fading in, so the first sound in the
    /// room completes a rep the user has not even seen the words for. This is
    /// the difference between measuring speech and measuring noise.
    private let readingGraceSeconds: TimeInterval = 1.5
    /// The mic never stays armed longer than this, whatever the user does.
    private let maxListenSeconds: TimeInterval = 22

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var maxDurationTimer: Timer?
    private var voiceSince: Date?
    /// Levels sampled during the reading grace, used to learn the room.
    private var ambientSamples: [Float] = []
    /// The bar a sound has to clear, resolved once the grace period ends.
    private var resolvedThreshold: Float?
    /// When the mic went live, so the reading grace can be measured from it.
    private var listeningSince: Date?
    /// Whether THIS service activated the shared audio session.
    ///
    /// `stop()` is called unconditionally on dismissal, on the mic-denied path,
    /// and on the hold fallback — and deactivating a session we never activated
    /// tears down whatever else in the app was using it. Someone running the
    /// drill with worship playing had the music killed by a screen that never
    /// opened the mic at all.
    private var didActivateSession = false

    private var recordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("guard_voice_presence.m4a")
    }

    // MARK: - Permission

    /// Whether the mic has already been granted, without prompting. The view
    /// uses this to show its one-line reason BEFORE the system dialog, which is
    /// the difference between a permission people grant and one they don't.
    ///
    /// `nonisolated` so the view can read it without hopping actors just to ask
    /// a question the system answers synchronously.
    nonisolated static var micAlreadyAuthorized: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    nonisolated static var micPreviouslyDenied: Bool {
        AVAudioApplication.shared.recordPermission == .denied
    }

    /// Requests the mic only. Speech recognition authorization is deliberately
    /// NOT requested — there is no transcription here, so asking for it would be
    /// demanding a permission the feature does not use.
    func requestMicPermission() async -> Bool {
        if Self.micAlreadyAuthorized { return true }
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        permissionDenied = !granted
        return granted
    }

    // MARK: - Listening

    /// Arms the mic. Returns false when permission is unavailable, in which case
    /// the caller shows the press-and-hold fallback — never a nag.
    @discardableResult
    func start() async -> Bool {
        guard !isListening else { return true }
        guard await requestMicPermission() else { return false }

        do {
            let session = AVAudioSession.sharedInstance()
            // .duckOthers rather than interrupting: someone may be running this
            // during quiet time with worship playing.
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            didActivateSession = true

            // Use the session's negotiated rate — never hardcode 44100. On some
            // OS versions AVAudioRecorder traps during format init when they
            // disagree. Same lesson as DeclarationVerificationService.
            let sampleRate = session.sampleRate > 0 ? session.sampleRate : 44100.0
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
            ]

            let recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            self.recorder = recorder
        } catch {
            print("⚠️ VoicePresenceService: could not start listening — \(error.localizedDescription)")
            return false
        }

        levels = []
        heardVoice = false
        timedOutWithoutVoice = false
        voiceSince = nil
        ambientSamples = []
        resolvedThreshold = nil
        listeningSince = Date()
        isListening = true

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sampleLevel() }
        }
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: maxListenSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.timeOut() }
        }
        return true
    }

    /// The window closed with nothing heard. Stops the mic AND says so, so the
    /// view has something to react to instead of a silent dead end.
    private func timeOut() {
        guard isListening, !heardVoice else { return }
        stop()
        timedOutWithoutVoice = true
    }

    /// Stops and cleans up. Safe to call repeatedly, and safe to call when never
    /// started — the flow's dismissal path does exactly that.
    func stop() {
        meterTimer?.invalidate(); meterTimer = nil
        maxDurationTimer?.invalidate(); maxDurationTimer = nil
        recorder?.stop()
        recorder = nil
        isListening = false
        voiceSince = nil
        listeningSince = nil
        ambientSamples = []
        resolvedThreshold = nil
        // The audio is the one thing this feature could keep and must not. It
        // goes the moment listening ends.
        try? FileManager.default.removeItem(at: recordingURL)
        // Only if we activated it. See `didActivateSession`.
        if didActivateSession {
            didActivateSession = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// The no-mic path. Same verdict, same log, no second-class treatment.
    func confirmSpokenByHold() {
        heardVoice = true
    }

    /// The bar for this particular room, computed once when the grace ends.
    ///
    /// Ambient is taken as the MEDIAN of the grace samples rather than the mean,
    /// so one slammed door during those 1.5 seconds cannot drag the bar up out
    /// of reach for the rest of the screen.
    private func resolveThreshold() -> Float {
        if let resolvedThreshold { return resolvedThreshold }

        var threshold: Float = minimumVoiceThreshold
        if !ambientSamples.isEmpty {
            let sorted: [Float] = ambientSamples.sorted()
            let median: Float = sorted[sorted.count / 2]
            let adaptive: Float = median + voiceMarginOverAmbient
            if adaptive > threshold { threshold = adaptive }
        }
        // Never demand a shout, however loud the room was during the grace.
        if threshold > 0.6 { threshold = 0.6 }
        resolvedThreshold = threshold
        return threshold
    }

    private func sampleLevel() {
        guard let recorder, isListening else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)   // dBFS, roughly -160...0
        // -50 dB floor reads as silence. Spelled out rather than nested
        // min/max: this feature already failed an archive on that shape.
        var normalized: Float = (power + 50) / 50
        if normalized < 0 { normalized = 0 }
        if normalized > 1 { normalized = 1 }
        levels.append(normalized)
        if levels.count > 48 { levels.removeFirst() }

        guard !heardVoice else { return }

        // Reading grace. The mic is live from the moment the screen appears so
        // the waveform can respond, but nothing counts as a spoken declaration
        // until the user has had time to read the line. The grace doubles as the
        // window in which the room is measured.
        if let listeningSince, Date().timeIntervalSince(listeningSince) < readingGraceSeconds {
            ambientSamples.append(normalized)
            return
        }

        let threshold: Float = resolveThreshold()
        if normalized >= threshold {
            let since = voiceSince ?? Date()
            voiceSince = since
            if Date().timeIntervalSince(since) >= sustainedVoiceSeconds {
                heardVoice = true
            }
        } else {
            // A breath between clauses shouldn't reset the whole measurement,
            // but a long silence should — otherwise a cough at the start plus a
            // cough at the end would add up to "spoken".
            if let since = voiceSince, Date().timeIntervalSince(since) > 2 {
                voiceSince = nil
            }
        }
    }
}
