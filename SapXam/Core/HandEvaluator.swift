import Foundation

/// Shared ordinal scale for poker hand strength, used for BOTH the 5-card (middle/back)
/// and reduced 3-card (front) evaluators so a front hand can be compared directly against
/// a middle/back hand when checking the back ≥ middle ≥ front arrangement rule. A 3-card
/// hand can only ever land on .highCard, .onePair, or .threeOfAKind (no 3-card straights or
/// flushes count toward hand *strength* here — see `HandEvaluator.evaluate3`), but reusing
/// the same enum lets a 3-card three-of-a-kind compare correctly against, say, a 5-card
/// straight (threeOfAKind < straight, exactly as it should).
enum HandCategory: Int, Comparable {
    case highCard = 0
    case onePair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush

    static func < (lhs: HandCategory, rhs: HandCategory) -> Bool { lhs.rawValue < rhs.rawValue }

    var labelKey: String {
        switch self {
        case .highCard: return "hand.highCard"
        case .onePair: return "hand.onePair"
        case .twoPair: return "hand.twoPair"
        case .threeOfAKind: return "hand.threeOfAKind"
        case .straight: return "hand.straight"
        case .flush: return "hand.flush"
        case .fullHouse: return "hand.fullHouse"
        case .fourOfAKind: return "hand.fourOfAKind"
        case .straightFlush: return "hand.straightFlush"
        }
    }
}

/// A fully-evaluated hand: its category plus a tie-break list compared lexicographically,
/// highest-priority element first (e.g. for two pair: [highPairRank, lowPairRank, kicker]).
/// Shorter tie-break lists (the 3-card evaluator emits fewer elements than the 5-card one)
/// are treated as zero-padded on the right when compared against a longer list — this is
/// exactly what lets a front hand compare safely against a middle/back hand.
struct HandValue: Comparable, Equatable {
    let category: HandCategory
    let tiebreakers: [Int]

    static func < (lhs: HandValue, rhs: HandValue) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        let n = max(lhs.tiebreakers.count, rhs.tiebreakers.count)
        for i in 0..<n {
            let l = i < lhs.tiebreakers.count ? lhs.tiebreakers[i] : 0
            let r = i < rhs.tiebreakers.count ? rhs.tiebreakers[i] : 0
            if l != r { return l < r }
        }
        return false
    }

    static func == (lhs: HandValue, rhs: HandValue) -> Bool {
        lhs.category == rhs.category && lhs.tiebreakers == rhs.tiebreakers
    }
}

enum HandEvaluator {
    /// Poker rank value: 2 is the lowest card, Ace the highest (standard poker order).
    /// Deliberately independent of `Rank.rawValue`, which encodes the *Vietnamese shedding
    /// game* order (2 highest) used by other apps in this portfolio — Sập Xám is a poker
    /// variant, so hand evaluation needs standard poker card values instead.
    static func pokerValue(_ rank: Rank) -> Int {
        switch rank {
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .jack: return 11
        case .queen: return 12
        case .king: return 13
        case .ace: return 14
        }
    }

    /// Evaluate a 3-card front hand. Only high card / pair / three of a kind are possible —
    /// a 3-card "straight" or "flush" does NOT count as a straight/flush for hand strength
    /// (standard Chinese-poker-family rule); it just falls through to high card.
    static func evaluate3(_ cards: [Card]) -> HandValue {
        precondition(cards.count == 3, "front hand must be exactly 3 cards")
        let values = cards.map { pokerValue($0.rank) }.sorted(by: >)
        var counts: [Int: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }

        if let triple = counts.first(where: { $0.value == 3 })?.key {
            return HandValue(category: .threeOfAKind, tiebreakers: [triple])
        }
        if let pair = counts.first(where: { $0.value == 2 })?.key {
            let kicker = values.first { $0 != pair } ?? 0
            return HandValue(category: .onePair, tiebreakers: [pair, kicker])
        }
        return HandValue(category: .highCard, tiebreakers: values)
    }

    /// Evaluate a full 5-card poker hand (middle or back).
    static func evaluate5(_ cards: [Card]) -> HandValue {
        precondition(cards.count == 5, "middle/back hand must be exactly 5 cards")
        let values = cards.map { pokerValue($0.rank) }.sorted(by: >)
        let suits = cards.map { $0.suit }
        let isFlush = Set(suits).count == 1

        var counts: [Int: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        // Groups sorted by (count desc, rank desc) — e.g. full house -> [(triple,3),(pair,2)].
        let groups = counts.sorted { a, b in a.value != b.value ? a.value > b.value : a.key > b.key }

        let straightHigh = straightHighCard(values)
        let isStraight = straightHigh != nil

        if isStraight, isFlush {
            return HandValue(category: .straightFlush, tiebreakers: [straightHigh!])
        }
        if groups.first?.value == 4 {
            let quad = groups[0].key
            let kicker = groups[1].key
            return HandValue(category: .fourOfAKind, tiebreakers: [quad, kicker])
        }
        if groups.count >= 2, groups[0].value == 3, groups[1].value == 2 {
            return HandValue(category: .fullHouse, tiebreakers: [groups[0].key, groups[1].key])
        }
        if isFlush {
            return HandValue(category: .flush, tiebreakers: values)
        }
        if isStraight {
            return HandValue(category: .straight, tiebreakers: [straightHigh!])
        }
        if groups[0].value == 3 {
            let kickers = groups.dropFirst().map { $0.key }
            return HandValue(category: .threeOfAKind, tiebreakers: [groups[0].key] + kickers)
        }
        if groups.count >= 2, groups[0].value == 2, groups[1].value == 2 {
            let highPair = max(groups[0].key, groups[1].key)
            let lowPair = min(groups[0].key, groups[1].key)
            let kicker = groups[2].key
            return HandValue(category: .twoPair, tiebreakers: [highPair, lowPair, kicker])
        }
        if groups[0].value == 2 {
            let kickers = groups.dropFirst().map { $0.key }
            return HandValue(category: .onePair, tiebreakers: [groups[0].key] + kickers)
        }
        return HandValue(category: .highCard, tiebreakers: values)
    }

    /// Returns the straight's high card value (poker order) if `values` (sorted desc, may
    /// contain duplicates for a 5-card hand that isn't a straight) form 5 consecutive ranks.
    /// Supports the A-2-3-4-5 wheel (returns 5 as the "high card" for the wheel, standard
    /// poker convention) in addition to normal runs and the A-high broadway straight.
    private static func straightHighCard(_ values: [Int]) -> Int? {
        let unique = Array(Set(values)).sorted(by: >)
        guard unique.count == 5 else { return nil }
        if zip(unique, unique.dropFirst()).allSatisfy({ $0 == $1 + 1 }) {
            return unique[0]
        }
        // Wheel: A,5,4,3,2
        if unique == [14, 5, 4, 3, 2] {
            return 5
        }
        return nil
    }
}
