//
//  DailyDeclaration.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/1/22.
//

import Foundation


public enum DeclarationCategory: String, CaseIterable, Identifiable, Codable,  Comparable {
    public static func < (lhs: DeclarationCategory, rhs: DeclarationCategory) -> Bool {
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
    case relationship   // dating / courting / pre-marriage relationship
    case general
    case praise
    case heaven
    case purity
    case love
    case gratitude
    case warfare
    case anxiety
    case favor
    case work
    case business       // entrepreneur / own business
    case grief          // loss / bereavement
    case fertility      // infertility / believing for a child
    case salvation      // praying for unsaved or prodigal loved ones
    case debt           // specific crushing debt / financial bondage
    case education      // school / exams / degree
    case housing        // home / rent / eviction / housing need
    case divorce        // divorce recovery / going through divorce
    case wellness       // body / weight / health habits / body image
    case mentalHealth   // clinical mental health / PTSD / bipolar / OCD
    case forgiveness    // forgiving others / bitterness / resentment
    case newSeason      // fresh start / new chapter / starting over
    case singleParent   // raising kids alone
    case anger          // anger / rage / temper
    case speaklife
    case innerHealing
    case obedience
    case spiritualGrowth
    case miracles
    case friendship
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
    
    public static var allCategories: [DeclarationCategory] = [
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
        .innerHealing, // might get rid of these
        
        // Tier 4 - Daily Walk
        .obedience,
       // .spiritualGrowth, // might get rid of these
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
       // .fear, // might get rid of these
        .hardtimes,
        .addiction,
        
        // Tier 8 - Eternal Perspective
//        .heaven, // might get rid of these
//        .confidence, // might get rid of these
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
    
    public static var bibleCategories: [DeclarationCategory] = [
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
    
    public static var generalCategories: [DeclarationCategory] = [
        .general,
        .speaklife,
        .favorites,
        .myOwn,
        ]
    
    
    public static var categoryOrder: [DeclarationCategory] = [
        // Tier 1 - Foundation (God & Identity)
       // .speaklife,
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
       // .spiritualGrowth,
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
       // .confidence
    ]
    
    public var isBibleBook: Bool {
        return DeclarationCategory.bibleCategories.contains(where: { $0 == self } )
    }
    public var id: String {
         self.rawValue
    }

    public var name: String {
        switch self {
       // case .selfcontrol: return "Self Control"
        case .godsheart: return "God's Heart"
        case .spiritualGrowth: return "Spiritual Growth"
        case .obedience: return "Surrender & Obedience"
        case .innerHealing: return "Emotional & Inner Healing"
        case .work: return "Work & Career"
        case .miracles: return "Miracles & Breakthroughs"
        case .friendship: return "Friendship & Support"
        case .favor: return "Favor & Blessings"
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
    
    
    public var imageString: String {
        if DeclarationCategory.bibleCategories.contains(self) {
            return "wisdom"
        }
        switch self {
        default:
            return self.rawValue.lowercased()
        }
    }

    public var categoryTitle: String {
        switch self {
        case .myOwn:
            return "My Own"
        default:
            return name
        }
    }

    public init?(_ name: String) {
        self.init(rawValue: name.lowercased())
    }

    public var isPremium: Bool {
        switch self {
        case .general, .favorites, .myOwn, .faith, .health, .anxiety, .gratitude: return false
        default: return true
        }
    }
}

public struct Updates: Codable {
    public let currentDeclarationVersion: Int?

    public init(currentDeclarationVersion: Int?) {
        self.currentDeclarationVersion = currentDeclarationVersion
    }
}

// MARK: - Welcome
public struct Welcome: Codable {
    public let count: Int
    public let version: Int
    public let declarations: [Declaration]

    public init(count: Int, version: Int, declarations: [Declaration]) {
        self.count = count
        self.version = version
        self.declarations = declarations
    }
}

// MARK: - Content Type
public enum ContentType: String, Codable, CaseIterable {
    case affirmation = "affirmation"
    case journal = "journal"

    public var displayName: String {
        switch self {
        case .affirmation: return "Affirmation"
        case .journal: return "Journal"
        }
    }

    public var pluralDisplayName: String {
        switch self {
        case .affirmation: return "Affirmations"
        case .journal: return "Journals"
        }
    }

    public var icon: String {
        switch self {
        case .affirmation: return "quote.bubble"
        case .journal: return "book.pages"
        }
    }
}

// MARK: - Declaration
public struct Declaration: Codable, Identifiable, Hashable {
    public let text: String
    public var book: String? = nil
    public var bibleVerseText: String? = nil
    public var category: DeclarationCategory = .faith
    public var categories: [DeclarationCategory] = []
    public var isFavorite: Bool? = false
    public var contentType: ContentType = .affirmation
    public var id: String {
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

    public var lastEdit: Date?

    // Custom decoder to handle missing contentType in existing data
    public init(from decoder: Decoder) throws {
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
    public init(text: String, book: String? = nil, bibleVerseText: String? = nil, category: DeclarationCategory = .faith, categories: [DeclarationCategory] = [], isFavorite: Bool? = false, contentType: ContentType = .affirmation, lastEdit: Date? = nil) {
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

// MARK: - Personal Declaration Focus Choice Labels

extension DeclarationCategory {
    public var focusEmoji: String {
        switch self {
        case .health:         return "🙏"
        case .wealth:         return "💰"
        case .work:           return "💼"
        case .business:       return "🚀"
        case .love:           return "💍"
        case .relationship:   return "💛"
        case .marriage:       return "👫"
        case .parenting:      return "👶"
        case .destiny:        return "🌟"
        case .identity:       return "🪞"
        case .rest:           return "😌"
        case .joy:            return "☀️"
        case .favor:          return "🚪"
        case .grace:          return "🕊️"
        case .godsprotection: return "🛡️"
        case .addiction:      return "⛓️"
        case .confidence:     return "💪"
        case .fear:           return "🧠"
        case .wisdom:         return "💡"
        case .innerHealing:   return "❤️‍🩹"
        case .spiritualGrowth: return "🌱"
        case .miracles:       return "✨"
        case .hardtimes:      return "⛰️"
        case .warfare:        return "⚔️"
        case .friendship:     return "🤝"
        case .purity:         return "🕊️"
        case .hope:           return "🌅"
        case .anxiety:        return "🫁"
        case .grief:          return "🕊️"
        case .fertility:      return "🌱"
        case .salvation:      return "🙏"
        case .debt:           return "⛓️"
        case .education:      return "📚"
        case .housing:        return "🏠"
        case .divorce:        return "💔"
        case .wellness:       return "💪"
        case .mentalHealth:   return "🧠"
        case .forgiveness:    return "🤍"
        case .newSeason:      return "🌅"
        case .singleParent:   return "👪"
        case .anger:          return "🔥"
        default:              return "🙏"
        }
    }

    /// What an Enforcement campaign is named after, as in "Enforcing Victory".
    ///
    /// Never `name` and never `focusTitle`. Both are browse labels, built to sit
    /// in a category picker where naming the struggle is how someone finds their
    /// row: "Anxiety & Worry", "Hard Times", "Peace Over Anxiety". Put "Enforcing"
    /// in front of those and the card announces that the user is enforcing their
    /// anxiety, which is the exact inversion of the feature and a rule 12
    /// violation in the loudest type on the screen.
    ///
    /// So this returns the victory, never the topic. It matches what the four
    /// hand-authored campaigns in `enforcements.json` already do (Enforcing
    /// Peace, Provision, Healing, Victory), which the assembled path was
    /// silently failing to follow.
    ///
    /// Titles are allowed to repeat across categories. Two people enforcing
    /// Freedom from different things is fine; the campaign is named for where
    /// they are going, not for where they came from.
    public var enforcementTitle: String {
        switch self {
        // The fight
        case .warfare:         return "Victory"
        case .fear:            return "Courage"
        case .hardtimes:       return "Strength"
        case .godsprotection:  return "Protection"

        // The mind and the heart
        case .anxiety:         return "Peace"
        case .anger:           return "Peace"
        case .mentalHealth:    return "A Sound Mind"
        case .rest:            return "Rest"
        case .joy:             return "Joy"
        case .hope:            return "Hope"
        case .innerHealing:    return "Inner Healing"
        case .grief:           return "Comfort"

        // The body
        case .health:          return "Healing"
        case .wellness:        return "Wholeness"

        // Provision
        case .wealth:          return "Provision"
        case .debt:            return "Freedom"
        case .housing:         return "My Home"
        case .business:        return "Increase"
        case .work:            return "My Work"
        case .education:       return "My Studies"

        // Who I am and where I am going
        case .destiny:         return "My Purpose"
        case .identity:        return "My Identity"
        case .confidence:      return "Boldness"
        case .wisdom:          return "Wisdom"
        case .favor:           return "Favor"
        case .newSeason:       return "My New Season"
        case .miracles:        return "Breakthrough"

        // Freedom
        case .addiction:       return "Freedom"
        case .forgiveness:     return "Freedom"
        case .purity:          return "Purity"
        case .grace:           return "Grace"

        // People
        case .marriage:        return "My Marriage"
        case .relationship:    return "My Relationship"
        case .love:            return "Love"
        case .parenting:       return "My Children"
        case .singleParent:    return "My Household"
        case .friendship:      return "Friendship"
        case .divorce:         return "Restoration"
        case .fertility:       return "God's Promise"
        case .salvation:       return "Salvation"

        // Walking with God
        case .faith:           return "Faith"
        case .spiritualGrowth: return "My Walk With God"
        case .obedience:       return "Surrender"
        case .gratitude:       return "Gratitude"
        case .praise:          return "Praise"

        // The card's own eyebrow reads ENFORCE THE VICTORY, so an unmapped
        // category lands on the feature's own word rather than falling back to
        // `name` and reintroducing "Enforcing Anxiety & Worry".
        default:               return "Victory"
        }
    }

    public var focusTitle: String {
        switch self {
        case .health:         return "My Healing"
        case .wealth:         return "Financial Breakthrough"
        case .work:           return "My Career"
        case .business:       return "My Business"
        case .love:           return "Finding a Spouse"
        case .relationship:   return "My Relationship"
        case .marriage:       return "My Marriage"
        case .parenting:      return "My Children"
        case .destiny:        return "My Purpose & Calling"
        case .identity:       return "My Identity in God"
        case .rest:           return "Peace & Rest"
        case .joy:            return "Joy & Freedom from Depression"
        case .favor:          return "God's Favor & Open Doors"
        case .grace:          return "Forgiveness & Freedom from Shame"
        case .godsprotection: return "God's Protection"
        case .addiction:      return "Freedom from Addiction"
        case .confidence:     return "Boldness & Confidence"
        case .fear:           return "Freedom from Fear"
        case .wisdom:         return "Wisdom & Clarity"
        case .innerHealing:   return "Inner Healing"
        case .spiritualGrowth: return "Growing Closer to God"
        case .miracles:       return "A Miracle"
        case .hardtimes:      return "Strength Through Hard Times"
        case .warfare:        return "Spiritual Victory"
        case .friendship:     return "Community & Friendship"
        case .purity:         return "Purity & Holiness"
        case .hope:           return "Hope & Expectation"
        case .anxiety:        return "Peace Over Anxiety"
        case .grief:          return "Grief & Loss"
        case .fertility:      return "Fertility & Pregnancy"
        case .salvation:      return "Salvation of a Loved One"
        case .debt:           return "Breaking Out of Debt"
        case .education:      return "School & Education"
        case .housing:        return "A Home"
        case .divorce:        return "Divorce Recovery"
        case .wellness:       return "Body & Health Habits"
        case .mentalHealth:   return "Mental Health"
        case .forgiveness:    return "Forgiving Someone"
        case .newSeason:      return "A Fresh Start"
        case .singleParent:   return "Single Parenting"
        case .anger:          return "Anger & Temper"
        default:              return "My Belief"
        }
    }

    public var focusSubtitle: String {
        switch self {
        case .work:         return "Career, promotion, employment"
        case .business:     return "Starting or growing your own business"
        case .love:         return "Believing for a godly spouse"
        case .relationship: return "Dating, courting, or a relationship you're in"
        case .marriage:     return "Protecting or restoring your marriage"
        case .grief:        return "Loss of a loved one"
        case .fertility:    return "Infertility, pregnancy, believing for a child"
        case .salvation:    return "Praying for a prodigal or unsaved loved one"
        case .debt:         return "Breaking free from financial bondage"
        case .education:    return "School, exams, graduation"
        case .housing:      return "Finding or keeping a home"
        case .divorce:      return "Healing and rebuilding after divorce"
        case .wellness:     return "Weight, body image, healthy habits"
        case .mentalHealth: return "Clinical mental health, PTSD, diagnosis"
        case .forgiveness:  return "Releasing bitterness toward someone who hurt you"
        case .newSeason:    return "Starting over, new chapter, fresh beginning"
        case .singleParent: return "Raising children alone"
        case .anger:        return "Controlling anger, rage, or temper"
        default:            return "Declare God's word over this area"
        }
    }
}
