import Foundation

enum Suit: Int, CaseIterable, Comparable {
    case spades = 0, clubs, diamonds, hearts // ascending tie-break priority

    static func < (lhs: Suit, rhs: Suit) -> Bool { lhs.rawValue < rhs.rawValue }

    var symbol: String {
        switch self {
        case .spades: return "♠"
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        }
    }

    var isRed: Bool { self == .diamonds || self == .hearts }
}

/// Rank order low -> high: 3,4,5,6,7,8,9,10,J,Q,K,A,2 ("heo", the pig, is the strongest single).
enum Rank: Int, CaseIterable, Comparable {
    case three = 0, four, five, six, seven, eight, nine, ten, jack, queen, king, ace, two

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        case .two: return "2"
        }
    }

    /// Sequential rank for straight-run checks (2 is excluded from straights, like Tiến Lên).
    var isStraightEligible: Bool { self != .two }
}

struct Card: Identifiable, Hashable {
    let id = UUID()
    let rank: Rank
    let suit: Suit

    var label: String { "\(rank.label)\(suit.symbol)" }

    /// Point value used for end-of-round scoring (opponents' unplayed cards).
    var pointValue: Int { rank.rawValue + 1 }
}

extension Array where Element == Card {
    static func freshDeck() -> [Card] {
        Suit.allCases.flatMap { suit in Rank.allCases.map { Card(rank: $0, suit: suit) } }
    }
}
