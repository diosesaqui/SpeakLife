//
//  AppGroupsDebugView.swift
//  SpeakLife
//
//  Debug view to test App Groups configuration
//

import SwiftUI
import WidgetKit

// Helper to access widget UserDefaults
private let widgetDefaults = UserDefaults(suiteName: "group.com.speaklife.widget")

struct AppGroupsDebugView: View {
    @State private var testValue = ""
    @State private var readValue = ""
    @State private var favorites: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("App Groups Debug")
                .font(.largeTitle)
                .padding()
            
            // Test basic App Groups
            VStack(alignment: .leading, spacing: 10) {
                Text("App Group Available: \(widgetDefaults != nil ? "✅ YES" : "❌ NO")")
                    .foregroundColor(widgetDefaults != nil ? .green : .red)
                
                Text("Suite Name: group.com.speaklife.widget")
                
                Divider()
                
                // Test write/read
                HStack {
                    TextField("Test value", text: $testValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Write") {
                        widgetDefaults?.set(testValue, forKey: "debugTest")
                        print("Wrote:", testValue)
                    }
                    
                    Button("Read") {
                        readValue = widgetDefaults?.string(forKey: "debugTest") ?? "nil"
                        print("Read:", readValue)
                    }
                }
                
                Text("Read value: \(readValue)")
                
                Divider()
                
                // Favorites test
                Text("Widget Favorites: \(favorites.count) items")
                
                Button("Load Favorites") {
                    favorites = widgetDefaults?.stringArray(forKey: "widgetFavorites") ?? []
                    print("Loaded \(favorites.count) favorites")
                }
                
                Button("Add Test Favorite") {
                    var current = widgetDefaults?.stringArray(forKey: "widgetFavorites") ?? []
                    current.append("Test favorite \(Date().timeIntervalSince1970)")
                    widgetDefaults?.set(current, forKey: "widgetFavorites")
                    favorites = current
                    
                    // Trigger widget refresh
                    WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
                }
                
                Button("Clear All Favorites") {
                    widgetDefaults?.removeObject(forKey: "widgetFavorites")
                    favorites = []
                    WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
                }
                .foregroundColor(.red)
                
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(favorites, id: \.self) { favorite in
                            Text("• \(favorite)")
                                .font(.caption)
                                .lineLimit(2)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding()
            
            Spacer()
        }
        .onAppear {
            favorites = widgetDefaults?.stringArray(forKey: "widgetFavorites") ?? []
            
            // Debug print
            print("🔍 AppGroupsDebugView loaded")
            print("   App Group available:", widgetDefaults != nil)
            print("   Favorites count:", favorites.count)
        }
    }
}

struct AppGroupsDebugView_Previews: PreviewProvider {
    static var previews: some View {
        AppGroupsDebugView()
    }
}