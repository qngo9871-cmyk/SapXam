import Foundation

enum RoundPhase {
    case arranging   // human still arranging (no instant win in play this round)
    case resolved    // round scored, results on screen
}

/// Outcome of one of the 3 sub-hand comparisons (front/middle/back) between two players,
/// from playerA's point of view: +1 A wins, -1 A loses, 0 tie.
struct SubHandResult {
    let position: String   // "front" | "middle" | "back"
    let outcome: Int
}

enum PairReason {
    case normal
    case special   // resolved via instant-win multiplier, not a card-by-card comparison
    case foul      // one (or both) sides fouled their arrangement
}

struct PairResult {
    let playerA: Int
    let playerB: Int
    let swing: Int   // units gained by playerA (playerB loses the same amount)
    let reason: PairReason
    var subResults: [SubHandResult] = []
    var scooped: Bool = false   // true if one side won/lost all 3 sub-hands
}

struct RoundResult {
    let swings: [Int]              // per-player net swing this round
    let pairDetails: [PairResult]
    let specialWinners: [Int: SpecialHandKind]
}

/// Drives a full Sập Xám match: 2-4 players (1 human + AI), 13 cards dealt fresh each round,
/// arrange-then-compare scoring. No fixed round count and no forced stakes — the player ends
/// the match whenever they want (deliberate differentiator, see CLAUDE.md).
final class GameModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var playerCount: Int = 4
    @Published var difficulty: AIDifficulty = .easy
    @Published var roundNumber: Int = 0
    @Published var phase: RoundPhase = .arranging
    @Published var matchScores: [Int] = []
    @Published var roundResult: RoundResult?
    @Published var matchOver: Bool = false

    /// Scoop bonus (in units) for winning all 3 sub-hands against one opponent. Common
    /// convention across Chinese-poker-family implementations; documented in CLAUDE.md.
    static let scoopBonus = 3

    func displayName(_ index: Int) -> String {
        guard players.indices.contains(index) else { return "" }
        return L(players[index].nameKey)
    }

    func startMatch(playerCount: Int, difficulty: AIDifficulty) {
        self.playerCount = max(2, min(4, playerCount))
        self.difficulty = difficulty
        matchScores = Array(repeating: 0, count: self.playerCount)
        roundNumber = 0
        matchOver = false
        startRound()
    }

    func startRound() {
        roundNumber += 1
        roundResult = nil

        var deck = Array<Card>.freshDeck().shuffled()
        var newPlayers: [Player] = []
        for i in 0..<playerCount {
            let hand = Array(deck.prefix(13))
            deck.removeFirst(13)
            let key = i == 0 ? "player.you" : "player.ai\(i)"
            var p = Player(id: i, nameKey: key, hand: hand, isHuman: i == 0)
            p.specialHand = SpecialHandDetector.detect(hand: hand)
            newPlayers.append(p)
        }
        players = newPlayers

        let specials = players.reduce(into: [Int: SpecialHandKind]()) { dict, p in
            if let s = p.specialHand { dict[p.id] = s }
        }

        if !specials.isEmpty {
            resolveSpecialRound(specials)
            return
        }

        for i in players.indices where !players[i].isHuman {
            players[i].arrangement = AIArranger.arrange(hand: players[i].hand, difficulty: difficulty)
        }
        phase = .arranging
    }

    /// AI-assist for the human player — always searches at Hard depth regardless of the
    /// match's AI difficulty, since this is a UX convenience (auto-arrange button), not an
    /// opponent's strength.
    func suggestedArrangement() -> Arrangement? {
        guard players.indices.contains(0) else { return nil }
        return AIArranger.arrange(hand: players[0].hand, difficulty: .hard)
    }

    func submitHumanArrangement(_ arrangement: Arrangement) {
        guard players.indices.contains(0) else { return }
        players[0].arrangement = arrangement
        scoreRound()
    }

    func endMatch() {
        matchOver = true
    }

    // MARK: - Scoring

    private func resolveSpecialRound(_ specials: [Int: SpecialHandKind]) {
        var swings = Array(repeating: 0, count: playerCount)
        var details: [PairResult] = []

        for i in 0..<playerCount {
            for j in (i + 1)..<playerCount {
                let a = specials[i]
                let b = specials[j]
                var swing = 0
                switch (a, b) {
                case (nil, nil):
                    swing = 0
                case (let sa?, nil):
                    swing = sa.multiplier
                case (nil, let sb?):
                    swing = -sb.multiplier
                case (let sa?, let sb?):
                    if sa.multiplier == sb.multiplier { swing = 0 }
                    else { swing = sa.multiplier - sb.multiplier }
                }
                swings[i] += swing
                swings[j] -= swing
                details.append(PairResult(playerA: i, playerB: j, swing: swing, reason: .special))
            }
        }
        applyRoundSwings(swings, details, specials)
    }

    private func scoreRound() {
        var swings = Array(repeating: 0, count: playerCount)
        var details: [PairResult] = []

        for i in 0..<playerCount {
            for j in (i + 1)..<playerCount {
                guard let ai = players[i].arrangement, let aj = players[j].arrangement else { continue }
                let result = compare(ai, i, aj, j)
                swings[i] += result.swing
                swings[j] -= result.swing
                details.append(result)
            }
        }
        applyRoundSwings(swings, details, [:])
    }

    private func compare(_ a: Arrangement, _ ai: Int, _ b: Arrangement, _ bi: Int) -> PairResult {
        let aFouled = a.isFouled
        let bFouled = b.isFouled

        if aFouled && bFouled {
            return PairResult(playerA: ai, playerB: bi, swing: 0, reason: .foul)
        }
        if aFouled {
            return PairResult(playerA: ai, playerB: bi, swing: -(3 + Self.scoopBonus), reason: .foul, scooped: true)
        }
        if bFouled {
            return PairResult(playerA: ai, playerB: bi, swing: 3 + Self.scoopBonus, reason: .foul, scooped: true)
        }

        var subResults: [SubHandResult] = []
        var aWins = 0, bWins = 0
        let positions: [(String, HandValue?, HandValue?)] = [
            ("front", a.frontValue, b.frontValue),
            ("middle", a.middleValue, b.middleValue),
            ("back", a.backValue, b.backValue),
        ]
        for (name, av, bv) in positions {
            guard let av, let bv else { continue }
            if av > bv {
                aWins += 1
                subResults.append(SubHandResult(position: name, outcome: 1))
            } else if av < bv {
                bWins += 1
                subResults.append(SubHandResult(position: name, outcome: -1))
            } else {
                subResults.append(SubHandResult(position: name, outcome: 0))
            }
        }

        var swing = aWins - bWins
        var scooped = false
        if aWins == 3 { swing += Self.scoopBonus; scooped = true }
        if bWins == 3 { swing -= Self.scoopBonus; scooped = true }

        return PairResult(playerA: ai, playerB: bi, swing: swing, reason: .normal, subResults: subResults, scooped: scooped)
    }

    private func applyRoundSwings(_ swings: [Int], _ details: [PairResult], _ specials: [Int: SpecialHandKind]) {
        for i in 0..<playerCount where matchScores.indices.contains(i) {
            matchScores[i] += swings[i]
        }
        roundResult = RoundResult(swings: swings, pairDetails: details, specialWinners: specials)
        phase = .resolved
    }
}
