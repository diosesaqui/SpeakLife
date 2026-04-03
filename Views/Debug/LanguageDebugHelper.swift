//
//  LanguageDebugHelper.swift
//  SpeakLife
//
//  Debug helper to check localization status
//

import Foundation
import SwiftUI

#if DEBUG
struct LanguageDebugHelper {
    static func printCurrentLanguageStatus() {
        print("🔍 LANGUAGE DEBUG STATUS")
        print("========================")
        
        // System language
        let systemLanguage = Locale.preferredLanguages.first ?? "unknown"
        print("📱 System Language: \(systemLanguage)")
        
        // App language manager
        let appLanguage = LanguageManager.shared.currentLanguage.rawValue
        print("🚀 App Language: \(appLanguage)")
        
        // UserDefaults
        let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "none"
        print("💾 Saved Language: \(savedLanguage)")
        
        // Bundle check
        let spanishBundle = Bundle.main.path(forResource: "es", ofType: "lproj")
        print("📁 Spanish Bundle: \(spanishBundle != nil ? "✅ Found" : "❌ Missing")")
        
        // Test UI string
        let testString = String(localized: "tab_declarations")
        print("🎨 Test UI String 'tab_declarations': '\(testString)'")
        
        // File availability
        let spanishDeclarations = Bundle.main.url(forResource: "declarations_es", withExtension: "json")
        let spanishDevotionals = Bundle.main.url(forResource: "devotionals_es", withExtension: "json")
        print("📄 Spanish Declarations: \(spanishDeclarations != nil ? "✅ Found" : "❌ Missing")")
        print("📄 Spanish Devotionals: \(spanishDevotionals != nil ? "✅ Found" : "❌ Missing")")
        
        print("========================")
    }
    
    static func forceSpanishLanguage() {
        print("🔄 Forcing Spanish language...")
        LanguageManager.shared.setLanguage(.spanish)
        
        // Test immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            printCurrentLanguageStatus()
        }
    }
    
    static func resetToSystemLanguage() {
        print("🔄 Resetting to system language...")
        
        // Clear saved preference
        UserDefaults.standard.removeObject(forKey: "selectedLanguage")
        
        // Create new language manager instance to trigger detection
        let _ = LanguageManager()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            printCurrentLanguageStatus()
        }
    }
}

// Add this to your app delegate or main view for testing
extension View {
    func debugLanguageStatus() -> some View {
        self.onAppear {
            LanguageDebugHelper.printCurrentLanguageStatus()
        }
    }
}
#endif