# Structured Day MVP — Checklist Deep-Linking
**Goal:** Reduce cancellations by ensuring every checklist task takes users to the right place in the app.  
**Root cause:** Users have a checklist, but tapping tasks did nothing — no navigation, no guidance.

---

## What Was Broken

| Task | Before | After |
|---|---|---|
| Complete Daily Burst | Checkbox only | Dismisses checklist → fires `ShowDailyDeclarationBurst` notification → full-screen burst |
| Read Daily Devotional | Checkbox only | Opens Devotional sheet inline |
| Listen to Audio | Checkbox only | Picks best audio filter by onboarding category → switches to Audio tab → highlights first unplayed episode |
| Express Gratitude | Checkbox only | Stays checkbox (no destination needed for MVP) |

---

## Files Changed

### New: `Services/AudioPlayer/AudioRecommendationEngine.swift`
Pure-logic engine. No state, no UI. Maps `DeclarationCategory` raw values to audio filter IDs.

**How it works:**
1. Takes user's `userSelectedCategories` from UserDefaults (set during onboarding)
2. Looks up priority-ordered filter IDs for each category (e.g. `anxiety` → `["meditation", "speaklife"]`)
3. Returns the first filter ID that actually exists in the user's loaded audio content
4. Within that filter, returns the first **unplayed** episode (via `AudioProgressStore.shared.isPlayed()`)
5. If all episodes played → wraps back to episode 1 (restart from beginning)

**Category → Filter mapping:**
- `anxiety`, `fear` → `meditation` (fear/anxiety meditations)
- `identity` → `meditation` (identity meditation)
- `health` → `divineHealth`
- `warfare`, `godsprotection` → `divineHealth` / `psalm91`
- `wisdom`, `joy`, `love`, `rest`, `praise`, `gratitude` → `meditation`
- `faith`, `grace`, `destiny`, `hope`, `confidence` → `speaklife`
- `general`, `friendship`, `innerhealing` → `growWithJesus`
- `marriage`, `parenting`, `wealth`, `favor`, `work`, `miracles` → `declarations`
- `godsheart` → `godsHeart`
- `heaven` → `gospel`
- Default fallback: `speaklife`

---

### Modified: `DailyChecklistModels.swift`

Added:
```swift
enum TaskNavigationDestination: String, Codable {
    case none       // checkbox only
    case audioTab   // → Audio tab + recommendation
    case devotional // → Devotional sheet
    case burst      // → Daily Declaration Burst
}
```

Added `navigationDestination: TaskNavigationDestination` to `DailyTask` struct.  
Updated `TaskLibrary.foundationTasks` with correct destinations.  
`personalizeTask()` auto-preserves destination (struct copy).

---

### Modified: `AudioDeclarationViewModel.swift`

Added:
```swift
@Published var checklistRecommendedEpisode: AudioDeclaration? = nil
```

Set by the checklist before switching to the audio tab. The AudioDeclarationView can observe this to auto-scroll to / highlight the recommended episode (future enhancement).

---

### Modified: `ModernDailyChecklistView.swift`

Added `@EnvironmentObject` for `AudioDeclarationViewModel` and `TabViewModel` (both already in env chain from `SpeakLifeApp`).

Added `handleTaskNavigation(_ task: DailyTask)`:
- `.audioTab` → compute recommendation → `audioDeclarationViewModel.setSelectedFilter()` → `dismiss()` → `tabViewModel.goToAudio()` (delayed 0.35s for sheet animation)
- `.devotional` → `showDevotional = true` (existing sheet)
- `.burst` → `dismiss()` → post `ShowDailyDeclarationBurst` notification (existing listener in HomeView)
- `.none` → `viewModel.completeTask()` inline

Updated `OptimizedTaskRow`:
- Added `onNavigate: (DailyTask) -> Void` parameter
- Checkbox tap → `onToggle` (unchanged)
- Row body tap → `onNavigate` (new)
- Shows "→ Open" affordance on incomplete navigable tasks

---

## UX Flow (Audio Example)

1. User opens checklist
2. Sees "Listen to Identity Audio" (personalized from onboarding)
3. Taps the row body → sees "→ Open" affordance
4. Checklist dismisses
5. Audio tab opens, pre-filtered to `meditation` (best match for "identity")
6. First unplayed meditation episode is ready to play
7. User listens → `AudioProgressStore` marks it played
8. Tomorrow: next unplayed episode recommended automatically

---

## What's NOT in this MVP

- Auto-complete the audio task when user finishes listening (future: observe `AudioProgressStore` changes)
- Auto-scroll to the recommended episode in AudioDeclarationView (future: use `checklistRecommendedEpisode`)
- RevenueCat / MRR tracking of retention improvement

---

## Testing Checklist

- [ ] Tap "Complete Daily Burst" → burst full-screen appears
- [ ] Tap "Read Daily Devotional" → devotional sheet opens
- [ ] Tap "Listen to [Category] Audio" → audio tab opens with right filter
- [ ] User with `anxiety` category → opens `meditation` filter
- [ ] User with `health` category → opens `divineHealth` filter
- [ ] User with no categories → defaults to `speaklife` filter
- [ ] All episodes played → recommends episode 1 again (no dead end)
- [ ] Checkbox still toggles completion independently
