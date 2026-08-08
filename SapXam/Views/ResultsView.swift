import SwiftUI

/// End-of-round scoring screen: your arranged hand, each opponent's hand, a win/loss/tie
/// icon per sub-hand, scoop callouts, and the net point swing — or, on an instant-win round,
/// a "tới trắng" banner instead of a card-by-card comparison.
struct ResultsView: View {
    @ObservedObject var game: GameModel
    var onNextRound: () -> Void
    var onEndMatch: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.1, blue: 0.22).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text(String(format: L("game.round"), game.roundNumber))
                        .font(.caption).foregroundStyle(.white.opacity(0.6))

                    if let result = game.roundResult, !result.specialWinners.isEmpty {
                        specialBanner(result)
                    } else if game.players.first?.arrangement != nil {
                        myHandSummary
                    }

                    if let result = game.roundResult {
                        ForEach(1..<game.playerCount, id: \.self) { opponent in
                            opponentCard(opponent: opponent, result: result)
                        }
                        totalSummary(result)
                    }
                }
                .padding()
                // Reserves scroll space so the floating button bar below never
                // permanently hides the last opponent's hand / match scores —
                // without this, a 4-player match's tail content sits underneath
                // the buttons with no way to scroll it fully into view.
                .padding(.bottom, 76)
            }

            VStack {
                Spacer()
                HStack(spacing: 14) {
                    Button(L("game.endMatch")) { onEndMatch() }
                        .buttonStyle(.bordered).tint(.gray)
                    Button(L("game.nextRound")) { onNextRound() }
                        .buttonStyle(.borderedProminent).tint(.green)
                }
                .padding(.bottom, 20)
            }
        }
    }

    private func specialBanner(_ result: RoundResult) -> some View {
        VStack(spacing: 10) {
            ForEach(result.specialWinners.sorted(by: { $0.key < $1.key }), id: \.key) { playerIndex, kind in
                VStack(spacing: 4) {
                    Text("⚡️ \(game.displayName(playerIndex))")
                        .font(.headline).foregroundStyle(.yellow)
                    Text(String(format: L("results.specialWin"), L(kind.titleKey), kind.multiplier))
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var myHandSummary: some View {
        VStack(spacing: 8) {
            Text(L("results.yourHand")).font(.caption.bold()).foregroundStyle(.white.opacity(0.7))
            if let a = game.players.first?.arrangement {
                handRow(title: L("arrange.back"), cards: a.back)
                handRow(title: L("arrange.middle"), cards: a.middle)
                handRow(title: L("arrange.front"), cards: a.front)
                if a.isFouled {
                    Text(L("results.youFouled")).font(.caption.bold()).foregroundStyle(.red)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func handRow(title: String, cards: [Card]) -> some View {
        HStack {
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.6)).frame(width: 52, alignment: .leading)
            HStack(spacing: -8) {
                ForEach(cards) { CardView(card: $0, width: 30) }
            }
            Spacer()
            if cards.count == 3 {
                Text(L(HandEvaluator.evaluate3(cards).category.labelKey)).font(.caption2).foregroundStyle(.yellow)
            } else if cards.count == 5 {
                Text(L(HandEvaluator.evaluate5(cards).category.labelKey)).font(.caption2).foregroundStyle(.yellow)
            }
        }
    }

    private func opponentCard(opponent: Int, result: RoundResult) -> some View {
        guard let pair = result.pairDetails.first(where: {
            ($0.playerA == 0 && $0.playerB == opponent) || ($0.playerA == opponent && $0.playerB == 0)
        }) else { return AnyView(EmptyView()) }

        let swingForMe = pair.playerA == 0 ? pair.swing : -pair.swing
        let opponentArrangement = game.players[safe: opponent]?.arrangement

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(game.displayName(opponent)).font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    Text(swingForMe > 0 ? "+\(swingForMe)" : "\(swingForMe)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(swingForMe > 0 ? .green : (swingForMe < 0 ? .red : .white.opacity(0.6)))
                }

                if pair.reason == .foul {
                    Text(swingForMe > 0 ? L("results.opponentFouled") : L("results.youFouled"))
                        .font(.caption).foregroundStyle(.orange)
                } else if let arrangement = opponentArrangement {
                    handRow(title: L("arrange.back"), cards: arrangement.back)
                    handRow(title: L("arrange.middle"), cards: arrangement.middle)
                    handRow(title: L("arrange.front"), cards: arrangement.front)
                    HStack(spacing: 10) {
                        ForEach(pair.subResults, id: \.position) { sub in
                            let mine = pair.playerA == 0 ? sub.outcome : -sub.outcome
                            Label(sub.position.capitalized, systemImage: mine > 0 ? "checkmark.circle.fill" : (mine < 0 ? "xmark.circle.fill" : "equal.circle.fill"))
                                .font(.caption2)
                                .foregroundStyle(mine > 0 ? .green : (mine < 0 ? .red : .white.opacity(0.5)))
                        }
                    }
                    if pair.scooped {
                        Text(L("results.scoop")).font(.caption2.bold()).foregroundStyle(.yellow)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        )
    }

    private func totalSummary(_ result: RoundResult) -> some View {
        VStack(spacing: 6) {
            Text(L("results.matchScores")).font(.caption.bold()).foregroundStyle(.white.opacity(0.7))
            ForEach(0..<game.playerCount, id: \.self) { i in
                HStack {
                    Text(game.displayName(i)).foregroundStyle(i == 0 ? .yellow : .white.opacity(0.8))
                    Spacer()
                    Text("\(game.matchScores[safe: i] ?? 0)").monospacedDigit()
                        .foregroundStyle(i == 0 ? .yellow : .white.opacity(0.8))
                }
                .font(.caption)
            }
        }
        .padding(.top, 60)
        .padding(.horizontal)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let g = GameModel()
    g.startMatch(playerCount: 4, difficulty: .easy)
    if let human = g.players.first {
        g.submitHumanArrangement(AIArranger.arrange(hand: human.hand, difficulty: .hard))
    }
    return ResultsView(game: g, onNextRound: {}, onEndMatch: {})
}
