//
//  LanguageDetectionFix.swift
//  SpeakLife
//
//  Force language detection fix for simulator testing
//

import Foundation
import SwiftUI

struct LanguageDetectionFix {
    static func detectAndSetLanguage() {
        let systemLanguages = Locale.preferredLanguages
        let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage")
        
        print("🔍 Language Detection Debug:")
        print("System Languages: \(systemLanguages.prefix(5))")
        print("Saved Language: \(savedLanguage ?? "none")")
        
        // If no saved language, detect from system
        if savedLanguage == nil {
            let primaryLanguage = systemLanguages.first ?? "en"
            let isSpanish = primaryLanguage.hasPrefix("es")
            
            let detectedLanguage: LanguageManager.AppLanguage = isSpanish ? .spanish : .english
            
            print("🎯 Detected Language: \(detectedLanguage.rawValue)")
            
            // Set the language
            LanguageManager.shared.setLanguage(detectedLanguage)
            
            print("✅ Language set to: \(LanguageManager.shared.currentLanguage.rawValue)")
        }
        
        // Force update UI strings
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    static func forceSpanishForTesting() {
        print("🔄 Force setting Spanish for testing...")
        LanguageManager.shared.setLanguage(.spanish)
        
        // Test a UI string
        let testString = String(localized: "tab_declarations")
        print("🧪 Test string 'tab_declarations': '\(testString)'")
        
        // Force UI refresh
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
}