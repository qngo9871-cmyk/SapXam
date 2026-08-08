import Foundation

/// Turns a freshly-dealt 13-card hand into a non-fouling back/middle/front arrangement.
/// No precedent elsewhere in this portfolio — this is the hard, genuinely new part of
/// Sập Xám: there's no legal-move list to pick from like a shedding game, just a search
/// over which of the 1,287 possible 5-card back hands to commit to.
///
/// ## Approach
/// 1. Rank every possible 5-card **back** hand (all C(13,5) = 1,287 combinations) by
///    strength, descending.
/// 2. For each back candidate under consideration, pick the single best possible 5-card
///    **middle** from the remaining 8 cards (full C(8,5) = 56 enumeration — cheap). The
///    leftover 3 cards become **front**.
/// 3. Skip any candidate that fouls (front > middle or middle > back), then keep whichever
///    surviving candidate scores highest on a simple hand-strength heuristic.
///
/// ### Why this can never fully foul
/// Taking the *globally best* 5-card hand as back and the *globally best from what's left*
/// as middle is mathematically guaranteed never to foul: any 5-card subset of the
/// remaining 8 cards is also a valid candidate in the original 1,287-combo pool, so the
/// true-best back is never beaten by the best-of-remainder middle; the same argument
/// (augment any 3-card set with the 2 best leftover kickers to get a valid middle
/// candidate) guarantees middle ≥ front too. That guarantee is exactly what search-width
/// 1 (Easy) relies on. Once the search considers *non-optimal* back candidates to chase
/// better overall EV (Normal/Hard), that guarantee no longer automatically holds for
/// those candidates specifically — so every candidate is explicitly foul-checked and
/// discarded if it fouls. Because the true-best-back candidate is always included in the
/// search (search width ≥ 1) and is always foul-free, a valid arrangement is always found.
///
/// Difficulty only changes how many back candidates get this treatment: Easy takes the
/// single best (fast, but doesn't consider trade-offs like sacrificing a bit of back
/// strength for a much stronger middle); Hard searches much deeper for a better overall
/// split. This is a heuristic, not a perfect solver, by design.
enum AIArranger {
    static func arrange(hand: [Card], difficulty: AIDifficulty) -> Arrangement {
        precondition(hand.count == 13, "AI arrangement requires exactly 13 cards")

        let searchWidth: Int
        switch difficulty {
        case .easy: searchWidth = 1
        case .normal: searchWidth = 10
        case .hard: searchWidth = 80
        }

        let rankedBacks = combinations(hand, 5)
            .map { (cards: $0, value: HandEvaluator.evaluate5($0)) }
            .sorted { $0.value > $1.value }

        var best: Arrangement?
        var bestScore = -Double.greatestFiniteMagnitude

        for backCandidate in rankedBacks.prefix(searchWidth) {
            let remaining8 = hand.filter { c in !backCandidate.cards.contains(where: { $0.id == c.id }) }
            guard remaining8.count == 8 else { continue }

            guard let bestMiddle = combinations(remaining8, 5)
                .map({ (cards: $0, value: HandEvaluator.evaluate5($0)) })
                .max(by: { $0.value < $1.value })
            else { continue }

            let front = remaining8.filter { c in !bestMiddle.cards.contains(where: { $0.id == c.id }) }
            guard front.count == 3 else { continue }

            let arrangement = Arrangement(front: front, middle: bestMiddle.cards, back: backCandidate.cards)
            guard !arrangement.isFouled else { continue }

            let score = evScore(arrangement)
            if score > bestScore {
                bestScore = score
                best = arrangement
            }
        }

        // The rank-1 back candidate is always foul-free (see doc comment above), so this
        // fallback should never actually trigger — it exists purely as a safety net.
        return best ?? safeFallback(hand)
    }

    /// Simple additive heuristic: category strength (0-8) per hand, weighted slightly
    /// toward front since a strong front is comparatively rarer/harder to secure than a
    /// strong back, plus a small fractional nudge from the primary tiebreaker so equally-
    /// categorized arrangements still prefer higher card values.
    private static func evScore(_ arrangement: Arrangement) -> Double {
        guard let f = arrangement.frontValue, let m = arrangement.middleValue, let b = arrangement.backValue else {
            return -1
        }
        func weighted(_ v: HandValue) -> Double {
            Double(v.category.rawValue) + Double(v.tiebreakers.first ?? 0) / 100.0
        }
        return weighted(b) + weighted(m) + weighted(f) * 1.2
    }

    /// Guaranteed non-fouling split used only if the main search unexpectedly finds nothing
    /// (should not happen in practice — see the proof above): the single globally-best back,
    /// paired with the single globally-best middle from what's left.
    private static func safeFallback(_ hand: [Card]) -> Arrangement {
        let back = combinations(hand, 5)
            .map { (cards: $0, value: HandEvaluator.evaluate5($0)) }
            .max { $0.value < $1.value }?.cards ?? Array(hand.prefix(5))
        let remaining8 = hand.filter { c in !back.contains(where: { $0.id == c.id }) }
        let middle = combinations(remaining8, 5)
            .map { (cards: $0, value: HandEvaluator.evaluate5($0)) }
            .max { $0.value < $1.value }?.cards ?? Array(remaining8.prefix(5))
        let front = remaining8.filter { c in !middle.contains(where: { $0.id == c.id }) }
        return Arrangement(front: front, middle: middle, back: back)
    }

    /// All k-card subsets of `array`, order-independent.
    static func combinations<T>(_ array: [T], _ k: Int) -> [[T]] {
        guard k > 0 else { return [[]] }
        guard array.count >= k else { return [] }
        if k == array.count { return [array] }
        var result: [[T]] = []
        result.reserveCapacity(1)
        for i in 0...(array.count - k) {
            let head = array[i]
            let tail = Array(array[(i + 1)...])
            for combo in combinations(tail, k - 1) {
                result.append([head] + combo)
            }
        }
        return result
    }
}
