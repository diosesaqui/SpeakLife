//
//  ClearBibleCache.swift
//  SpeakLife
//
//  Helper to clear Bible cache when switching APIs
//

import Foundation

// Add this method to your app's settings or debug menu to clear cache when needed
func clearBibleCacheForNewAPI() {
    let interactor = BibleInteractor()
    // Use the public clearCache method that's already in the protocol
    interactor.clearCache()
}