# Power-Up Feature Setup Guide

## 🚀 Quick Setup for Manual Testing

### Step 1: Add Files to Xcode Project
1. **Open Xcode**
2. **Right-click on project** → Add Files to "SpeakLife"
3. **Add these directories**:
   - `Services/Gamification/` (all files)
   - `Views/PowerUp/` (all files)
   - `SpeakLifeTests/Gamification/` (test files)

### Step 2: Update SpeakLifeApp.swift
```swift
// Add to the top of SpeakLifeApp.swift
import Firebase

@main
struct SpeakLifeApp: App {
    
    init() {
        // Your existing Firebase config
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState())
                // Add these lines:
                .initializePowerUps()
                .withPowerUpAlerts()
        }
    }
}
```

### Step 3: Update ProfileView.swift
```swift
// In ProfileView.swift, add this to your List:

var body: some View {
    List {
        // Your existing sections...
        
        // Add this new section:
        PowerUpProfileSection()
        
        // Rest of your sections...
    }
}
```

### Step 4: Test Basic Setup
Run the app and check:
- [ ] App builds without errors
- [ ] Profile view shows new "🎮 Gamification" section
- [ ] Tapping "Power-Up Settings" opens settings
- [ ] No crashes on startup

### Step 5: Test Notifications (Simulator)
```swift
// Add this temporary button for testing in ProfileView:

Button("🧪 Test Power-Up") {
    let testPowerUp = PowerUpNotification(
        basePoints: 20,
        multiplier: 3,
        type: .lightning,
        title: "⚡ TEST POWER-UP!",
        message: "This is a test - tap to catch!"
    )
    PowerUpNotificationService.shared.handlePowerUpTrigger(testPowerUp)
}
```

### Step 6: Firebase Setup (Optional for Testing)
For full functionality, ensure Firebase has these collections:
- `userProgress` (auto-created when first user syncs)
- `dailyChallenges` (auto-created)

## 🧪 Manual Testing Checklist

### Basic Functionality:
- [ ] App launches without crashes
- [ ] Power-Up section appears in Profile
- [ ] Settings screen opens and displays correctly
- [ ] Progress widget shows level 1, 0 XP
- [ ] Test button triggers power-up alert

### Power-Up Alert Testing:
- [ ] Alert appears with countdown timer
- [ ] Timer counts down from 30 seconds
- [ ] "SPEAK LIFE NOW!" button responds
- [ ] Alert dismisses after catch/timeout
- [ ] XP increases after successful catch
- [ ] Level progress bar updates

### Settings Testing:
- [ ] Toggle power-ups on/off
- [ ] Change frequency settings
- [ ] Modify active hours
- [ ] Progress widget reflects changes

### Edge Cases:
- [ ] Multiple rapid power-ups don't crash
- [ ] App backgrounding/foregrounding works
- [ ] Notification permissions handled gracefully

## 🐛 Common Issues & Fixes

### "PowerUpNotificationService not found"
- Ensure all files are added to Xcode target
- Check import statements

### "Firebase error"
- Verify GoogleService-Info.plist is included
- Check Firebase project settings

### Notifications not appearing
- Check notification permissions in Settings app
- Verify UNUserNotificationCenter delegate is set

### UI not updating
- Ensure @StateObject/@ObservedObject are used correctly
- Check that services are marked @Published

## 🚀 Ready for Testing When:
1. ✅ All files added to Xcode project
2. ✅ SpeakLifeApp.swift updated
3. ✅ ProfileView.swift updated  
4. ✅ App builds successfully
5. ✅ Test button triggers power-up alert
6. ✅ XP increases when catching power-ups

---

**Need Help?** Check console logs for error messages and verify all import statements are working.