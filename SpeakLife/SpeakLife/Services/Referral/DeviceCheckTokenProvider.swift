//
//  DeviceCheckTokenProvider.swift
//  SpeakLife
//
//  `DeviceTokenProviding` over Apple's DeviceCheck.
//
//  The token is what lets the server keep "a friend is counted exactly once"
//  (spec §2.5) honest across deleting the app and erasing the phone: Apple
//  holds two bits per device per developer team, and only the server can read
//  or set them, using this token.
//
//  Failure is normal here, not exceptional. The simulator and some devices are
//  unsupported, and Apple's service can be slow. Every caller sends its request
//  without a token rather than not at all; the server decides what an
//  unverifiable device gets (spec §7, `device_unverifiable`).
//

import Foundation
import DeviceCheck

@MainActor
final class DeviceCheckTokenProvider: DeviceTokenProviding {

    static let shared = DeviceCheckTokenProvider()

    private init() {}

    func token() async -> String? {
        guard DCDevice.current.isSupported else { return nil }
        do {
            let data = try await DCDevice.current.generateToken()
            return data.base64EncodedString()
        } catch {
            print("⚠️ DeviceCheck token failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Which Apple DeviceCheck endpoint the server must query.
    ///
    /// Only a DEBUG build signed for development gets development tokens.
    /// TestFlight and App Store builds are distribution-signed and get
    /// production tokens, so a sandbox receipt is NOT the signal here, even
    /// though it is for StoreKit. Sending the wrong environment makes Apple
    /// reject the token and the claim lands as `retry_later` forever.
    var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
