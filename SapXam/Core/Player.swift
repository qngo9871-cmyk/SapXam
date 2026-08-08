import Foundation

struct Player: Identifiable {
    let id: Int
    var nameKey: String
    var hand: [Card] = []
    let isHuman: Bool
    var arrangement: Arrangement? = nil
    var specialHand: SpecialHandKind? = nil
}

enum AIDifficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .easy: return "difficulty.easy"
        case .normal: return "difficulty.normal"
        case .hard: return "difficulty.hard"
        }
    }
}
