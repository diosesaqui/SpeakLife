# Generic Sectioned Layout System

A reusable, extensible system for creating Netflix-style sectioned layouts in any tab.

## Architecture Overview

```
┌─────────────────────────────────────┐
│          SectionedLayoutFactory     │ ← Factory for creating layouts
├─────────────────────────────────────┤
│         GenericSectionedView        │ ← Main sectioned view container
├─────────────────────────────────────┤
│       GenericHorizontalSection      │ ← Individual section component
├─────────────────────────────────────┤
│         GenericContentCell          │ ← Content cell (standard/compact/featured)
├─────────────────────────────────────┤
│           SectionProvider           │ ← Protocol for data providers
├─────────────────────────────────────┤
│         SectionableContent          │ ← Protocol for content items
└─────────────────────────────────────┘
```

## Key Components

### 1. Protocols

**`SectionableContent`**: Any content that can be sectioned
- Required: `id`, `title`, `subtitle`, `imageUrl`, `isPremium`
- Optional: `duration`, `tag`

**`SectionProvider`**: Provides sections for a specific content type
- `sections`: Array of sections to display
- `getFullSectionItems(sectionId:)`: Full items for "See All"
- `shouldUseSectionedLayout`: Whether to use sectioned layout

### 2. Generic Models

**`GenericSectionModel<T>`**: Generic section containing items of type T
**`GenericSectionConfiguration`**: Visual configuration (size, spacing, style)
**`SectionedTabConfig`**: Tab-specific configuration

### 3. Views

**`GenericSectionedView`**: Main vertical scrolling container
**`GenericHorizontalSection`**: Horizontal scrolling section
**`GenericContentCell`**: Configurable content cell

## Usage Examples

### Adding Sectioned Layout to New Tab

```swift
// 1. Update SectionedTabConfig enum
enum SectionedTabConfig {
    case speakLife      // ✅ Already implemented
    case devotionals    // ✅ Ready to use
    case testimonies    // 🔄 Add when needed
    case newTab         // 🆕 Your new tab
}

// 2. Create sections in AudioSectionProvider
private func createNewTabSections() -> [GenericSectionModel<AudioDeclaration>] {
    var sections: [GenericSectionModel<AudioDeclaration>] = []
    
    // Recent items
    sections.append(GenericSectionModel(
        id: "recent",
        title: "Recently Added",
        subtitle: "Latest content",
        items: getRecentItems(),
        configuration: .default,
        sectionType: .recent
    ))
    
    // Popular items
    sections.append(GenericSectionModel(
        id: "popular", 
        title: "Most Popular",
        subtitle: "Trending now",
        items: getPopularItems(),
        configuration: .featured,
        sectionType: .featured
    ))
    
    return sections
}

// 3. Update view to use sectioned layout
func episodeRow(_ proxy: GeometryProxy) -> some View {
    Group {
        if shouldUseSectionedLayout {
            speakLifeSectionedView  // Already works generically!
        } else {
            audioListView(proxy)
        }
    }
}
```

### Creating Custom Content Type

```swift
// 1. Create your content model
struct DevotionalItem: SectionableContent {
    let id: String
    let title: String
    let subtitle: String
    let imageUrl: String
    let isPremium: Bool
    let duration: String?
    
    // Devotional-specific properties
    let series: String
    let week: Int
    let scripture: String
}

// 2. Create section provider
class DevotionalSectionProvider: SectionProvider {
    typealias ContentType = DevotionalItem
    
    var sections: [GenericSectionModel<DevotionalItem>] {
        // Create devotional-specific sections
    }
    
    func getFullSectionItems(sectionId: String) -> [DevotionalItem] {
        // Return full list for section
    }
}

// 3. Use in view
GenericSectionedView(
    sectionProvider: DevotionalSectionProvider(),
    onItemTap: { devotional in /* handle tap */ },
    onFavoriteTap: { devotional in /* handle favorite */ }
)
```

## Configuration Options

### Cell Styles
- `.standard`: Default card layout (160x200)
- `.compact`: Horizontal row layout (140x180)
- `.featured`: Large hero cards (280x160)
- `.custom(width, height)`: Custom dimensions

### Section Types
- `.featured`: Hero/highlighted content
- `.favorites`: User's favorited items
- `.recent`: Recently added content
- `.standard`: Regular content sections
- `.continueListening`: Partially consumed content

## Current Status

✅ **Complete**: Generic foundation, SpeakLife implementation
🔄 **Ready**: Devotionals structure (needs content)
🆕 **Future**: Testimonies, custom tabs

## Migration Path

### Phase 1: Current (Done ✅)
- SpeakLife uses sectioned layout
- Generic system ready for other tabs

### Phase 2: Easy Addition (15 minutes per tab)
```swift
// Enable devotionals
case .devotionals: return true // in shouldUseSectionedLayout

// Add sections
private func createDevotionalSections() -> [...] {
    // Group by series, topic, etc.
}
```

### Phase 3: Custom Content Types (if needed)
- Create new `SectionableContent` conforming types
- Create dedicated section providers
- Full customization available

## Benefits

✅ **Consistent UX**: Same interaction patterns across tabs
✅ **Easy to Add**: New tabs get sectioned layout in minutes  
✅ **Highly Configurable**: Cell styles, sizes, behaviors
✅ **Type Safe**: Generic system with compile-time safety
✅ **Performance**: Lazy loading, efficient rendering
✅ **Testable**: Protocol-based, dependency injection

Ready to add sectioned layout to any tab with minimal effort! 🚀