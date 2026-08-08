//
//  AnthropicConfig.swift
//  SpeakLife
//
//  Endpoint config for the personalized-declaration generator.
//
//  The Anthropic API key, the model name, and the declaration-writing system
//  prompt all used to live here and were shipped to the device (the key arrived
//  via Remote Config at launch). They now live server-side in
//  `functions/declarationMatch.js`, which holds the key in Secret Manager,
//  enforces a per-user rate limit, and meters token usage. All that's left on
//  the device is which URL to call.
//

import Foundation

enum AnthropicConfig {
    // us-central1 HTTPS function for the speaklife-3e5c4 project.
    //
    // Local testing: set the scheme env var USE_FIREBASE_EMULATOR=1 (Edit Scheme
    // → Run → Arguments → Environment Variables) and run `firebase emulators:start`.
    // DEBUG builds will then hit the local emulator. Without the env var, and in
    // all Release builds, it always uses the production cloud URL. Same switch
    // Bible Chat uses — see BibleChatLocal.usesEmulator.
    private static let cloudEndpoint = URL(string: "https://us-central1-speaklife-3e5c4.cloudfunctions.net/declarationMatch")!
    private static let emulatorEndpoint = URL(string: "http://127.0.0.1:5001/speaklife-3e5c4/us-central1/declarationMatch")!

    static var endpoint: URL {
        BibleChatLocal.usesEmulator ? emulatorEndpoint : cloudEndpoint
    }
}
