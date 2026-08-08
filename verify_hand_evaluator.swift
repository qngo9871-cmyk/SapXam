import Foundation

// Ground-truth cross-validator for HandEvaluator / SpecialHandDetector, compiled directly
// against the ACTUAL shipped source files (not a reimplementation). Must be built with
// `swiftc` (not `swift <files>` script mode — multi-file script mode silently produces no
// output on this toolchain) into a binary named exactly "main.swift" for the entry file:
//   cp verify_hand_evaluator.swift /tmp/main.swift
//   swiftc SapXam/Core/Card.swift SapXam/Core/HandEvaluator.swift SapXam/Core/SpecialHand.swift \
//          SapXam/Core/Arrangement.swift /tmp/main.swift -o /tmp/verify_bin
//   /tmp/verify_bin

var failures = 0
var checks = 0

func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    checks += 1
    if condition() {
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name)")
    }
}

func c(_ rank: Rank, _ suit: Suit) -> Card { Card(rank: rank, suit: suit) }

// MARK: - 5-card category identification

let straightFlush = [c(.nine, .spades), c(.ten, .spades), c(.jack, .spades), c(.queen, .spades), c(.king, .spades)]
let fourKind = [c(.seven, .spades), c(.seven, .clubs), c(.seven, .diamonds), c(.seven, .hearts), c(.two, .spades)]
let fullHouse = [c(.king, .spades), c(.king, .clubs), c(.king, .diamonds), c(.four, .hearts), c(.four, .spades)]
let flush = [c(.two, .hearts), c(.five, .hearts), c(.nine, .hearts), c(.jack, .hearts), c(.king, .hearts)]
let straight = [c(.five, .spades), c(.six, .clubs), c(.seven, .diamonds), c(.eight, .hearts), c(.nine, .spades)]
let wheelStraight = [c(.ace, .spades), c(.two, .clubs), c(.three, .diamonds), c(.four, .hearts), c(.five, .spades)]
let trips = [c(.four, .spades), c(.four, .clubs), c(.four, .diamonds), c(.nine, .hearts), c(.two, .spades)]
let twoPairHigh = [c(.jack, .spades), c(.jack, .clubs), c(.eight, .diamonds), c(.eight, .hearts), c(.two, .spades)]
let twoPairLow = [c(.nine, .spades), c(.nine, .clubs), c(.eight, .diamonds), c(.eight, .hearts), c(.king, .spades)]
let onePair = [c(.three, .spades), c(.three, .clubs), c(.jack, .diamonds), c(.nine, .hearts), c(.two, .spades)]
let highCardAceKing = [c(.ace, .spades), c(.king, .clubs), c(.nine, .diamonds), c(.five, .hearts), c(.two, .spades)]
let highCardLow = [c(.eight, .spades), c(.six, .clubs), c(.five, .diamonds), c(.four, .hearts), c(.two, .spades)]

check("straight flush categorized correctly", HandEvaluator.evaluate5(straightFlush).category == .straightFlush)
check("four of a kind categorized correctly", HandEvaluator.evaluate5(fourKind).category == .fourOfAKind)
check("full house categorized correctly", HandEvaluator.evaluate5(fullHouse).category == .fullHouse)
check("flush categorized correctly", HandEvaluator.evaluate5(flush).category == .flush)
check("straight categorized correctly", HandEvaluator.evaluate5(straight).category == .straight)
check("wheel (A-2-3-4-5) recognized as straight", HandEvaluator.evaluate5(wheelStraight).category == .straight)
check("three of a kind categorized correctly", HandEvaluator.evaluate5(trips).category == .threeOfAKind)
check("two pair categorized correctly", HandEvaluator.evaluate5(twoPairHigh).category == .twoPair)
check("one pair categorized correctly", HandEvaluator.evaluate5(onePair).category == .onePair)
check("high card categorized correctly", HandEvaluator.evaluate5(highCardAceKing).category == .highCard)

// MARK: - Full category ordering (the actual ranking requested by the task)

let orderedWeakToStrong: [(String, [Card])] = [
    ("high card", highCardLow),
    ("one pair", onePair),
    ("two pair", twoPairLow),
    ("three of a kind", trips),
    ("straight", straight),
    ("flush", flush),
    ("full house", fullHouse),
    ("four of a kind", fourKind),
    ("straight flush", straightFlush),
]
for i in 0..<(orderedWeakToStrong.count - 1) {
    let (nameA, handA) = orderedWeakToStrong[i]
    let (nameB, handB) = orderedWeakToStrong[i + 1]
    check("\(nameB) beats \(nameA)", HandEvaluator.evaluate5(handB) > HandEvaluator.evaluate5(handA))
}

// MARK: - Kicker-based tie-breaking within the same category

check("two pair: higher top pair wins even with lower kicker rank",
      HandEvaluator.evaluate5(twoPairHigh) > HandEvaluator.evaluate5(twoPairLow))

let pairAceKicker = [c(.three, .spades), c(.three, .clubs), c(.ace, .diamonds), c(.nine, .hearts), c(.two, .spades)]
let pairKingKicker = [c(.three, .hearts), c(.three, .diamonds), c(.king, .clubs), c(.nine, .spades), c(.two, .clubs)]
check("one pair: same pair rank, higher kicker wins",
      HandEvaluator.evaluate5(pairAceKicker) > HandEvaluator.evaluate5(pairKingKicker))

let flushHigh = [c(.two, .clubs), c(.five, .clubs), c(.nine, .clubs), c(.jack, .clubs), c(.ace, .clubs)]
let flushLow = [c(.two, .diamonds), c(.five, .diamonds), c(.nine, .diamonds), c(.jack, .diamonds), c(.king, .diamonds)]
check("flush: higher top card wins", HandEvaluator.evaluate5(flushHigh) > HandEvaluator.evaluate5(flushLow))

let identicalA = [c(.nine, .spades), c(.nine, .clubs), c(.four, .diamonds), c(.two, .hearts), c(.seven, .spades)]
let identicalB = [c(.nine, .hearts), c(.nine, .diamonds), c(.four, .spades), c(.two, .clubs), c(.seven, .hearts)]
check("equal-rank hands (different suits) tie", HandEvaluator.evaluate5(identicalA) == HandEvaluator.evaluate5(identicalB))

// MARK: - 3-card front hand + cross-scale comparison against 5-card hands

let frontTrips = [c(.king, .spades), c(.king, .clubs), c(.king, .diamonds)]
let frontPair = [c(.jack, .spades), c(.jack, .clubs), c(.two, .diamonds)]
let frontHigh = [c(.ace, .spades), c(.nine, .clubs), c(.two, .diamonds)]

check("front: trips beats pair", HandEvaluator.evaluate3(frontTrips) > HandEvaluator.evaluate3(frontPair))
check("front: pair beats high card", HandEvaluator.evaluate3(frontPair) > HandEvaluator.evaluate3(frontHigh))
check("front trips (category=3) loses to a 5-card straight (category=4) — shared ordinal scale",
      HandEvaluator.evaluate5(straight) > HandEvaluator.evaluate3(frontTrips))
check("front trips beats a middle/back two pair — shared ordinal scale",
      HandEvaluator.evaluate3(frontTrips) > HandEvaluator.evaluate5(twoPairLow))

// MARK: - Arrangement foul detection

let validArrangement = Arrangement(front: frontHigh, middle: onePair, back: straightFlush)
check("valid back>=middle>=front arrangement is not fouled", !validArrangement.isFouled)

let fouledArrangement = Arrangement(front: frontTrips, middle: onePair, back: highCardLow)
check("front (trips) stronger than back (high card) is correctly flagged as fouled", fouledArrangement.isFouled)

// MARK: - SpecialHandDetector sanity checks

func hand13(_ pairs: [(Rank, Suit)]) -> [Card] { pairs.map { Card(rank: $0.0, suit: $0.1) } }

let allRanks: [Rank] = [.three, .four, .five, .six, .seven, .eight, .nine, .ten, .jack, .queen, .king, .ace, .two]

let rongCuon = allRanks.map { Card(rank: $0, suit: .spades) } // all 13 ranks, all spades
check("Rồng Cuốn detected (13 cards, one suit)", SpecialHandDetector.detect(hand: rongCuon) == .rongCuon)

let sanhRongMixed: [Card] = zip(allRanks, [Suit.spades, .hearts, .clubs, .diamonds, .spades, .hearts, .clubs, .diamonds, .spades, .hearts, .clubs, .diamonds, .spades]).map { Card(rank: $0.0, suit: $0.1) }
check("Sảnh Rồng detected (13 distinct ranks, mixed suits)", SpecialHandDetector.detect(hand: sanhRongMixed) == .sanhRong)

// Six pairs + 1 kicker: 3,3,4,4,5,5,6,6,7,7,8,8,9
let lucPheBon = hand13([
    (.three, .spades), (.three, .clubs), (.four, .spades), (.four, .clubs),
    (.five, .spades), (.five, .clubs), (.six, .spades), (.six, .clubs),
    (.seven, .spades), (.seven, .clubs), (.eight, .spades), (.eight, .clubs),
    (.nine, .spades),
])
check("Lục Phé Bôn detected (six pairs + 1 kicker)", SpecialHandDetector.detect(hand: lucPheBon) == .lucPheBon)

let noSpecial = hand13([
    (.three, .spades), (.three, .clubs), (.five, .diamonds), (.eight, .spades), (.jack, .clubs),
    (.king, .diamonds), (.two, .spades), (.four, .clubs), (.six, .diamonds), (.nine, .spades),
    (.queen, .clubs), (.seven, .diamonds), (.seven, .spades),
])
check("ordinary scattered hand has no special", SpecialHandDetector.detect(hand: noSpecial) == nil)

print("")
print("\(checks - failures)/\(checks) checks passed")
if failures > 0 {
    print("\(failures) FAILURES")
    exit(1)
} else {
    print("ALL CHECKS PASSED")
    exit(0)
}
