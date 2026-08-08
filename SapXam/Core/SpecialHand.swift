import Foundation

/// "Tới trắng" instant-win patterns detectable on a freshly-dealt 13-card hand, before any
/// arrangement happens. Closest structural precedent in this portfolio is SamLoc's
/// `InstantWin.swift` (a 10-card dealt-hand detector) — same idea, different game.
///
/// Priority order and multipliers follow the most detailed/consistent Vietnamese-language
/// source found during research (see `~/Projects/SapXam/CLAUDE.md` for citations and the
/// regional variation that was found — some sources give Lục Phé Bôn / Ba Cái Thùng / Ba
/// Cái Sảnh a flat x3, others x6; this build picks one internally-consistent decreasing
/// scale and documents the alternative).
enum SpecialHandKind: String, CaseIterable {
    case rongCuon     // Rồng Cuốn — 13-card straight, single suit (strongest)
    case sanhRong     // Sảnh Rồng — 13-card straight, mixed suits
    case lucPheBon    // Lục Phé Bôn — six pairs + 1 kicker
    case baCaiThung   // Ba Cái Thùng — three flushes (front/middle/back all same-suit)
    case baCaiSanh    // Ba Cái Sảnh — three straights (front/middle/back all consecutive runs)

    var titleKey: String {
        switch self {
        case .rongCuon: return "special.rongCuon"
        case .sanhRong: return "special.sanhRong"
        case .lucPheBon: return "special.lucPheBon"
        case .baCaiThung: return "special.baCaiThung"
        case .baCaiSanh: return "special.baCaiSanh"
        }
    }

    /// Payout multiplier applied against every opponent when this hand is dealt.
    var multiplier: Int {
        switch self {
        case .rongCuon: return 24
        case .sanhRong: return 12
        case .lucPheBon: return 6
        case .baCaiThung: return 3
        case .baCaiSanh: return 3
        }
    }
}

enum SpecialHandDetector {
    /// Checks a freshly-dealt 13-card hand for a "tới trắng" instant win, in priority order:
    /// Rồng Cuốn > Sảnh Rồng > Lục Phé Bôn > Ba Cái Thùng > Ba Cái Sảnh.
    static func detect(hand: [Card]) -> SpecialHandKind? {
        guard hand.count == 13 else { return nil }
        if isRongCuon(hand) { return .rongCuon }
        if isSanhRong(hand) { return .sanhRong }
        if isLucPheBon(hand) { return .lucPheBon }
        if isBaCaiThung(hand) { return .baCaiThung }
        if isBaCaiSanh(hand) { return .baCaiSanh }
        return nil
    }

    /// All 13 cards the same suit. Since a suit only contains one card per rank, this
    /// automatically also means one of every rank is present — a same-suit 13-card run.
    private static func isRongCuon(_ hand: [Card]) -> Bool {
        Set(hand.map(\.suit)).count == 1
    }

    /// One card of every rank (13 distinct ranks across 13 cards), but not all one suit
    /// (that stronger case is `rongCuon`, already checked first in `detect`).
    private static func isSanhRong(_ hand: [Card]) -> Bool {
        Set(hand.map(\.rank)).count == 13
    }

    /// Six pairs plus one single leftover card. A rank with 4 copies can supply 2 pairs.
    private static func isLucPheBon(_ hand: [Card]) -> Bool {
        var counts: [Rank: Int] = [:]
        for c in hand { counts[c.rank, default: 0] += 1 }
        let pairs = counts.values.reduce(0) { $0 + $1 / 2 }
        let leftover = 13 - pairs * 2
        return pairs == 6 && leftover == 1
    }

    /// Can the 13 cards be split into three monosuit groups sized 3, 5, 5 (front/middle/back)?
    /// Since 3+5+5 == 13 exactly, every card must be used, so this reduces to: can the four
    /// per-suit counts be covered by assigning each of {3,5,5} to some suit, with each suit's
    /// assigned total matching its actual card count exactly?
    private static func isBaCaiThung(_ hand: [Card]) -> Bool {
        var bySuit: [Suit: Int] = [:]
        for c in hand { bySuit[c.suit, default: 0] += 1 }
        let counts = Suit.allCases.map { bySuit[$0] ?? 0 }
        let targets = [3, 5, 5]
        for a in 0..<counts.count {
            for b in 0..<counts.count {
                for c in 0..<counts.count {
                    var sums = [Int](repeating: 0, count: counts.count)
                    sums[a] += targets[0]
                    sums[b] += targets[1]
                    sums[c] += targets[2]
                    if sums == counts { return true }
                }
            }
        }
        return false
    }

    /// Can the 13 cards be split into a 3-run and two 5-runs of consecutive ranks (suit
    /// irrelevant)? Supports the standard A-2-3-4-5 wheel for 5-runs. Exhaustive but tiny
    /// search (11 three-run windows × ~55 five-run window pairs).
    private static func isBaCaiSanh(_ hand: [Card]) -> Bool {
        var counts: [Int: Int] = [:]
        for c in hand { counts[HandEvaluator.pokerValue(c.rank), default: 0] += 1 }

        let threeWindows: [[Int]] = (2...12).map { s in [s, s + 1, s + 2] }
        var fiveWindows: [[Int]] = (2...10).map { s in [s, s + 1, s + 2, s + 3, s + 4] }
        fiveWindows.append([14, 2, 3, 4, 5]) // wheel: A-2-3-4-5

        func consume(_ c: inout [Int: Int], _ window: [Int]) -> Bool {
            for v in window {
                guard let n = c[v], n > 0 else { return false }
                c[v] = n - 1
            }
            return true
        }

        for w3 in threeWindows {
            for i in 0..<fiveWindows.count {
                for j in i..<fiveWindows.count {
                    var remaining = counts
                    if consume(&remaining, w3), consume(&remaining, fiveWindows[i]), consume(&remaining, fiveWindows[j]) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
