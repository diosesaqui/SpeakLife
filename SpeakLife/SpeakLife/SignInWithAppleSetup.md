# Sign in with Apple Setup Guide

## 1. Apple Developer Account Configuration

### Enable Sign in with Apple Capability:
1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select your **App ID**
4. Under **Capabilities**, enable **Sign in with Apple**
5. Save the configuration

## 2. Xcode Project Configuration

### Add Sign in with Apple Capability:
1. Open your project in Xcode
2. Select your **app target**
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Sign in with Apple**

### Required Entitlements:
Your `SpeakLife.entitlements` file should include:
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

## 3. Firebase Configuration

### Enable Apple Sign-In in Firebase:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method**
4. Enable **Apple** provider
5. Configure your **Services ID** (optional, for web)

### Add Required Dependencies:
In your `Package.swift` or Xcode project, ensure you have:
- `FirebaseAuth`
- `AuthenticationServices` (built-in iOS framework)

## 4. Code Implementation Checklist

### ✅ Required Files Added:
- `AppleSignInManager.swift` - Core Apple Sign In logic
- `CustomAppleSignInButton.swift` - UI components
- `AuthenticationTriggers.swift` - Trigger points

### ✅ Info.plist Configuration:
No additional Info.plist entries required for basic Sign in with Apple.

### ✅ Privacy Usage Description:
Add to Info.plist if collecting additional data:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>This allows us to provide personalized experiences.</string>
```

## 5. Testing

### Simulator Testing:
- Sign in with Apple works in iOS Simulator
- Use any Apple ID for testing
- Test both new account creation and existing account sign-in

### Device Testing:
- Requires actual iOS device
- Must be signed in to iCloud
- Apple ID must have two-factor authentication enabled

### Test Scenarios:
1. **First-time sign in** - Creates new account
2. **Returning user** - Signs in to existing account
3. **User cancellation** - Handles user dismissing the prompt
4. **Network failure** - Handles offline/connection issues
5. **Apple ID issues** - Handles Apple service problems

## 6. Production Considerations

### Apple Review Requirements:
- If you offer other sign-in methods, Sign in with Apple must be equally prominent
- Cannot require additional personal information if Apple ID doesn't provide it
- Must handle cases where user's Apple ID email is private relay

### Privacy Compliance:
- Respect user's choice to hide email (private relay)
- Don't require additional sign-up steps after Apple Sign In
- Handle account deletion properly

### Error Handling:
- Graceful fallback if Apple Sign In fails
- Clear error messages for users
- Retry mechanisms for network issues

## 7. Implementation Status

### ✅ Completed:
- Core Sign in with Apple integration
- Firebase authentication flow
- Error handling and validation
- UI components and flows

### 🔄 Next Steps:
1. Add the capability in Xcode project settings
2. Enable Apple provider in Firebase Console
3. Test on device with Apple ID
4. Handle edge cases and errors
5. Submit for App Store review

### 📱 Where Users See Sign In:
1. **Power-Up Username Setup** - When setting username
2. **Leaderboard Access** - When viewing rankings
3. **Profile Settings** - Manual sign in option
4. **App Launch** - New device setup
5. **Progress Protection** - When at risk of data loss

The implementation is ready - just needs the Xcode capability configuration!