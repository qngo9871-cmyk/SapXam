import Foundation

/// A player's 13 dealt cards split into three poker hands. `back` must be the strongest,
/// `front` the weakest — `isFouled` is true when that ordering is violated, which auto-loses
/// all 3 sub-hands against every opponent for the round (per Sập Xám / Chinese-poker-family
/// rules).
struct Arrangement {
    var front: [Card] = []   // 3 cards
    var middle: [Card] = []  // 5 cards
    var back: [Card] = []    // 5 cards

    var isComplete: Bool { front.count == 3 && middle.count == 5 && back.count == 5 }

    var frontValue: HandValue? { front.count == 3 ? HandEvaluator.evaluate3(front) : nil }
    var middleValue: HandValue? { middle.count == 5 ? HandEvaluator.evaluate5(middle) : nil }
    var backValue: HandValue? { back.count == 5 ? HandEvaluator.evaluate5(back) : nil }

    /// True if back ≥ middle ≥ front does NOT hold. Only meaningful once `isComplete`.
    var isFouled: Bool {
        guard isComplete, let f = frontValue, let m = middleValue, let b = backValue else { return false }
        return !(b >= m && m >= f)
    }

    var allCards: [Card] { front + middle + back }
}
