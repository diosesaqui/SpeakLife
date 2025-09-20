//
//  DailyDeclaration.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/1/22.
//

import Foundation


enum DeclarationCategory: String, CaseIterable, Identifiable, Codable,  Comparable {
    static func < (lhs: DeclarationCategory, rhs: DeclarationCategory) -> Bool {
        return  lhs.name <= rhs.name
    }
    case godsheart
    case destiny
    case faith
   
    case favorites
    case myOwn
   
    case fear
    case hope
    case health
    case wealth
    case wisdom
    case grace
  //  case motivation
    case addiction
    case confidence
    case godsprotection
    case rest
    case joy
    case hardtimes
    case parenting
    case identity
    case marriage
    case general
    case praise
    case heaven
    case purity
    case love
    case gratitude
    case warfare
    case anxiety
    case miracles
    case favor
    case work
    case speaklife
    case friendship
    case innerHealing
    case obedience
    case spiritualGrowth
    case blood
    case nameOfJesus
    case genesis, exodus, leviticus, numbers, deuteronomy
    case joshua, judges, ruth
    case samuel1, samuel2
    case kings1, kings2
    case chronicles1, chronicles2
    case ezra, nehemiah, esther
    case job, psalms, proverbs, ecclesiastes, songOfSolomon
    case isaiah, jeremiah, lamentations, ezekiel, daniel
    case hosea, joel, amos, obadiah, jonah, micah
    case nahum, habakkuk, zephaniah, haggai, zechariah, malachi
    
    // New Testament
    case matthew, mark, luke, john, acts
    case romans
    case corinthians1, corinthians2
    case galatians, ephesians, philippians, colossians
    case thessalonians1, thessalonians2
//    case timothy1, timothy2, titus, philemon
    case hebrews, james
    case peter1, peter2
    case john1, john2, john3, jude, revelation
    
    static var allCategories: [DeclarationCategory] = [
        // Special categories
        .favorites,
        .myOwn,
        
        // Tier 1 - Foundation (God & Identity)
        .speaklife,
        .love,
        .identity,
        .faith,
        .grace,
        
        // Tier 2 - Inner Life (Heart & Mind)
        .rest,  // Peace & Rest
        .hope,
        .joy,
        .wisdom,
        .praise,
        
        // Tier 3 - Transformation & Victory
        .destiny,
        .warfare,
        .miracles,
        .health,
        .innerHealing,
        
        // Tier 4 - Daily Walk
        .obedience,
        .spiritualGrowth,
        .purity,
        .gratitude,
        
        // Tier 5 - Relationships
        .marriage,
        .parenting,
        .friendship,
        
        // Tier 6 - Provision & Protection
        .godsprotection,
        .favor,
        .wealth,
        .work,
        
        // Tier 7 - Challenges & Struggles
        .anxiety,
        .fear,
        .hardtimes,
        .addiction,
        
        // Tier 8 - Eternal Perspective
        .heaven,
        .confidence,
        .genesis,
        .exodus,
        .leviticus,
        .numbers,
        .deuteronomy,
        .joshua,
        .judges,
        .ruth,
        .samuel1,
        .samuel2,
        .kings1,
        .kings2,
        .chronicles1,
        .chronicles2,
        .ezra,
        .psalms,
        .proverbs,
        .matthew,
        .mark,
        .luke,
        .john,
        .romans,
        .corinthians1,
        .corinthians2,
        .galatians,
        .ephesians,
        .philippians,
        .colossians,
        .hebrews,
        .james,
        .peter1,
        .peter2,
        .thessalonians1,
        .thessalonians2,
        .revelation,
        
        ]
    
    static var bibleCategories: [DeclarationCategory] = [
        .genesis,
        .exodus,
        .leviticus,
        .numbers,
        .deuteronomy,
        .joshua,
        .judges,
        .ruth,
        .samuel1,
        .samuel2,
        .kings1,
        .kings2,
        .chronicles1,
        .chronicles2,
        .ezra,
        .psalms,
        .proverbs,
        .matthew,
        .mark,
        .luke,
        .john,
        .romans,
        .corinthians1,
        .corinthians2,
        .galatians,
        .ephesians,
        .philippians,
        .colossians,
        .hebrews,
        .james,
        .peter1,
        .peter2,
        .thessalonians1,
        .thessalonians2,
        .revelation
        ]
    
    static var generalCategories: [DeclarationCategory] = [
        .general,
        .speaklife,
        .favorites,
        .myOwn,
        ]
    
    
    static var categoryOrder: [DeclarationCategory] = [
        // Tier 1 - Foundation (God & Identity)
        .speaklife,
        .love,
        .identity,
        .faith,
        .grace,
        
        // Tier 2 - Inner Life (Heart & Mind)
        .rest,  // Peace & Rest
        .hope,
        .joy,
        .wisdom,
        .praise,
        
        // Tier 3 - Transformation & Victory
        .destiny,
        .warfare,
        .miracles,
        .health,
        .innerHealing,
        
        // Tier 4 - Daily Walk
        .obedience,
        .spiritualGrowth,
        .purity,
        .gratitude,
        
        // Tier 5 - Relationships
        .marriage,
        .parenting,
        .friendship,
        
        // Tier 6 - Provision & Protection
        .godsprotection,
        .favor,
        .wealth,
        .work,
        
        // Tier 7 - Challenges & Struggles
        .anxiety,
        .fear,
        .hardtimes,
        .addiction,
        
        // Tier 8 - Eternal Perspective
        .heaven,
        .confidence
    ]
    
    var isBibleBook: Bool {
        return DeclarationCategory.bibleCategories.contains(where: { $0 == self } )
    }
    var id: String {
         self.rawValue
    }
    
    var name: String {
        switch self {
       // case .selfcontrol: return "Self Control"
        case .godsheart: return "God's Heart"
        case .spiritualGrowth: return "Spiritual Growth"
        case .obedience: return "Surrender & Obedience"
        case .innerHealing: return "Emotional & Inner Healing"
        case .friendship: return "Friendship & Support"
        case .work: return "Work & Career"
        case .favor: return "Favor & Blessings"
        case .miracles: return "Miracles & Breakthroughs"
        case .anxiety: return "Anxiety & Worry"
        case .warfare: return "Warfare & Victory"
        case .love: return "Love & Belonging"
        case .rest: return "Peace & Rest"
        case .hope: return "Hope & Endurance"
        case .destiny: return "Destiny"
        case .grace: return "Grace & Forgiveness"
        case .hardtimes: return "Hard Times"
        case .godsprotection: return "God's Protection"
        case .fear: return "Fear Not!"
        case .addiction: return "Overcome Addiction"
        case .heaven: return "Heavenly Thinking"
        case .purity: return "Purity"
        case .corinthians1: return "1 Corinthians"
        case .corinthians2: return "2 Corinthians"
        case .samuel1: return "1 Samuel"
        case .samuel2: return "2 Samuel"
        case .kings1: return "1 Kings"
        case .kings2: return "2 Kings"
        case .chronicles1: return "1 Chronicles"
        case .chronicles2: return "2 Chronicles"
        case .parenting: return "Raising children"
        case .peter1: return "1 Peter"
        case .peter2: return "2 Peter"
        case .thessalonians1: return "1 Thessalonians"
        case .thessalonians2: return "2 Thessalonians"
        case .speaklife: return "Speak Life Daily"
        case .blood: return "Blood of Jesus"
        case .nameOfJesus: return "Name of Jesus"
        default:  return self.rawValue.capitalized
        }
    }
    
    
    var imageString: String {
        if DeclarationCategory.bibleCategories.contains(self) {
            return "wisdom"
        }
        switch self {
        default:
            return self.rawValue.lowercased()
        }
    }
    
    var categoryTitle: String {
        switch self {
        case .myOwn:
            return "My Own"
        default:
            return name
        }
    }
    
    init?(_ name: String) {
        self.init(rawValue: name.lowercased())
    }
    
    var isPremium: Bool {
        switch self {
        case .general, .favorites, .myOwn, .faith, .health, .anxiety, .gratitude: return false
        default: return true
        }
    }
}

struct Updates: Codable {
    let currentDeclarationVersion: Int?
}

// MARK: - Welcome
struct Welcome: Codable {
    let count: Int
    let version: Int
    let declarations: [Declaration]
}

// MARK: - Content Type
enum ContentType: String, Codable, CaseIterable {
    case affirmation = "affirmation"
    case journal = "journal"
    
    var displayName: String {
        switch self {
        case .affirmation: return "Affirmation"
        case .journal: return "Journal"
        }
    }
    
    var pluralDisplayName: String {
        switch self {
        case .affirmation: return "Affirmations"
        case .journal: return "Journals"
        }
    }
    
    var icon: String {
        switch self {
        case .affirmation: return "quote.bubble"
        case .journal: return "book.pages"
        }
    }
}

// MARK: - Declaration
struct Declaration: Codable, Identifiable, Hashable {
    let text: String
    var book: String? = nil
    var bibleVerseText: String? = nil
    var category: DeclarationCategory = .faith
    var categories: [DeclarationCategory] = []
    var isFavorite: Bool? = false
    var contentType: ContentType = .affirmation
    var id: String {
       //UUID().uuidString
        text + category.rawValue + contentType.rawValue
    }
    
    enum CodingKeys: String, CodingKey {
            case text
            case book
            case bibleVerseText
            case category
            case isFavorite
            case lastEdit
            case contentType
        }
    
    var lastEdit: Date?
    
    // Custom decoder to handle missing contentType in existing data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        text = try container.decode(String.self, forKey: .text)
        book = try container.decodeIfPresent(String.self, forKey: .book)
        bibleVerseText = try container.decodeIfPresent(String.self, forKey: .bibleVerseText)
        category = try container.decodeIfPresent(DeclarationCategory.self, forKey: .category) ?? .faith
        categories = [] // Default empty array for backwards compatibility
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite)
        lastEdit = try container.decodeIfPresent(Date.self, forKey: .lastEdit)
        
        // Default to affirmation if contentType is missing (for backwards compatibility)
        contentType = try container.decodeIfPresent(ContentType.self, forKey: .contentType) ?? .affirmation
    }
    
    // Standard initializer
    init(text: String, book: String? = nil, bibleVerseText: String? = nil, category: DeclarationCategory = .faith, categories: [DeclarationCategory] = [], isFavorite: Bool? = false, contentType: ContentType = .affirmation, lastEdit: Date? = nil) {
        self.text = text
        self.book = book
        self.bibleVerseText = bibleVerseText
        self.category = category
        self.categories = categories
        self.isFavorite = isFavorite
        self.contentType = contentType
        self.lastEdit = lastEdit
    }
}
