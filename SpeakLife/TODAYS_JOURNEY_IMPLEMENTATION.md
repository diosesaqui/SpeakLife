# Today's Journey Feature - Implementation Guide

## Overview
"Today's Journey" is a personalized daily spiritual growth feature that creates customized task lists based on user's top 3 selected categories, integrating affirmations, audio content, devotionals, and voice meditation.

## Architecture Summary

### Core Components Created:
1. **Data Models** (`TodaysJourney.swift`)
   - JourneyTask: Individual task model with voice recording support
   - TodaysJourney: Daily journey container with theme and progress tracking
   - VoiceRecording: Audio meditation tracking
   - JourneyConfiguration: User preferences for journey generation

2. **ViewModel** (`TodaysJourneyViewModel.swift`)
   - Journey generation based on user categories
   - Task completion tracking
   - Voice recording management
   - Integration with existing ViewModels

3. **Views**
   - `TodaysJourneyView.swift`: Main journey dashboard
   - `TaskDetailView.swift`: Individual task interaction with voice meditation
   - `JourneyCelebrationView.swift`: Completion celebration screen

## Integration Steps

### Step 1: Add New Tab to HomeView
```swift
// In HomeView.swift, modify the TabView:
TabView(selection: $tabViewModel.selectedTab) {
    todaysJourneyView  // Add as first tab
    declarationView
    devotionalView
    audioView
    createYourOwnView
    profileView
}

// Add new view builder:
var todaysJourneyView: some View {
    TodaysJourneyView()
        .tag(0)  // Make it the first tab
        .tabItem {
            Image(systemName: "sun.max.fill")
                .renderingMode(.original)
            Text("Journey")
        }
}
```

### Step 2: Update TabViewModel
```swift
// Update indices in TabViewModel:
func resetToHome() {
    selectedTab = 0  // Now points to Today's Journey
}
```

### Step 3: Initialize ViewModel in App
```swift
// In SpeakLifeApp.swift:
@StateObject var todaysJourneyViewModel = TodaysJourneyViewModel(
    declarationViewModel: declarationStore,
    audioViewModel: audioDeclarationViewModel,
    devotionalViewModel: devotionalViewModel,
    streakViewModel: enhancedStreakViewModel
)

// Add to environment:
.environmentObject(todaysJourneyViewModel)
```

### Step 4: Category Selection Enhancement
```swift
// Add to DeclarationViewModel:
@Published var userTopCategories: [DeclarationCategory] = []

func updateTopCategories(_ categories: [DeclarationCategory]) {
    userTopCategories = categories
    // Trigger journey regeneration
    NotificationCenter.default.post(
        name: .categoriesUpdated,
        object: categories
    )
}
```

### Step 5: Add Category Picker to Profile
```swift
// Create CategorySelectionView.swift
struct CategorySelectionView: View {
    @EnvironmentObject var declarationViewModel: DeclarationViewModel
    @State private var selectedCategories: Set<DeclarationCategory> = []
    
    var body: some View {
        // Grid of categories with max 3 selection
        // Save button updates journey
    }
}
```

## Features Implementation

### Voice Meditation Flow
1. User taps verse meditation task
2. TaskDetailView opens with verse display
3. User holds mic button to record
4. Each recording increments counter
5. After 10 repetitions, task auto-completes

### Dynamic Task Generation
- **Foundation Phase (Days 1-7)**: Basic tasks (affirmation, devotional, gratitude)
- **Growth Phase (Days 8-30)**: Add memorization and worship
- **Impact Phase (Days 31-100)**: Add sharing and service tasks
- **Mastery Phase (100+)**: Advanced spiritual disciplines

### Personalization Algorithm
```swift
// Task selection based on categories:
1. Primary category → Morning affirmation + Audio
2. Secondary category → Bible verse for meditation
3. Tertiary category → Additional themed content
4. Streak progression → Difficulty and task types
```

## UI/UX Guidelines

### Design Principles (Apple Design Award Standards)
1. **Clarity**: Clean typography, clear task hierarchy
2. **Deference**: Content-first, minimal chrome
3. **Depth**: Layered interface with clear navigation
4. **Interaction**: Smooth animations, haptic feedback
5. **Consistency**: Follows existing SpeakLife design patterns

### Color System
- Each task type has unique color
- Gradient backgrounds from journey theme
- High contrast for accessibility

### Animations
- Spring animations for task completion
- Confetti celebration on journey completion
- Smooth progress ring updates
- Voice recording pulse animation

## Backend Requirements

### New Endpoints Needed
```swift
// Journey generation
POST /api/journey/generate
{
  "categories": ["faith", "healing", "abundance"],
  "streakDay": 15,
  "userId": "xxx"
}

// Journey completion tracking
POST /api/journey/complete
{
  "journeyId": "xxx",
  "completedTasks": [...],
  "totalTime": 25
}
```

### Database Schema Updates
```sql
-- New tables needed
CREATE TABLE user_journeys (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  date DATE,
  categories TEXT[],
  tasks JSONB,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE voice_recordings (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  journey_id UUID REFERENCES user_journeys(id),
  task_id UUID,
  file_url TEXT,
  duration INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## Testing Strategy

### Unit Tests
- Journey generation logic
- Task completion tracking
- Voice recording management
- Category-based content selection

### UI Tests
- Tab navigation to Journey
- Task interaction flow
- Voice recording permissions
- Celebration trigger

### Integration Tests
- Category changes trigger new journey
- Streak updates on completion
- Audio/devotional content loading

## Performance Considerations

1. **Cache Management**
   - Cache today's journey locally
   - Preload audio content for tasks
   - Store voice recordings efficiently

2. **Memory Optimization**
   - Lazy load task details
   - Release voice recordings after upload
   - Efficient image/gradient rendering

3. **Network Optimization**
   - Batch API calls for journey generation
   - Background upload for voice recordings
   - Offline mode support

## Analytics Events

```swift
// Track user engagement
Analytics.track("journey_started", properties: [
    "categories": journey.userCategories,
    "task_count": journey.tasks.count
])

Analytics.track("task_completed", properties: [
    "task_type": task.type,
    "duration": task.estimatedMinutes
])

Analytics.track("voice_meditation_completed", properties: [
    "repetitions": task.targetRepetitions,
    "verse": task.verseReference
])

Analytics.track("journey_completed", properties: [
    "streak_day": streakDay,
    "total_time": journey.estimatedTotalMinutes
])
```

## Launch Checklist

- [ ] Implement category selection UI in Profile
- [ ] Add Journey tab to main navigation
- [ ] Connect ViewModels and dependencies
- [ ] Test voice recording permissions
- [x] Custom confetti animation built with SwiftUI
- [ ] Create onboarding for new feature
- [ ] Update notification system for daily reminders
- [ ] Add journey-specific push notifications
- [ ] Implement analytics tracking
- [ ] Create A/B test variants
- [ ] Add feature flag for gradual rollout
- [ ] Update App Store screenshots
- [ ] Create marketing materials

## Migration Strategy

1. **Phase 1**: Launch as optional new tab
2. **Phase 2**: Prompt existing users to try it
3. **Phase 3**: Make it the default home tab
4. **Phase 4**: Migrate checklist users to Journey

## Success Metrics

- Daily Active Users (DAU) increase
- Task completion rate > 70%
- Voice meditation engagement > 40%
- Average session time increase
- Retention improvement D7/D30

## Future Enhancements

1. **AI-Powered Personalization**
   - ML model for task recommendations
   - Adaptive difficulty based on engagement

2. **Social Features**
   - Journey sharing with friends
   - Group challenges
   - Accountability partners

3. **Advanced Voice Features**
   - Voice sentiment analysis
   - Pronunciation coaching
   - Voice journal transcription

4. **Gamification**
   - Journey badges and achievements
   - Milestone rewards
   - Leaderboards

5. **Content Expansion**
   - Video devotionals
   - Guided meditation audio
   - Interactive Bible study