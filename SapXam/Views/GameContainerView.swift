import SwiftUI

/// Hosts one match: swaps between the arrange screen and the results screen each round,
/// and shows a final standings overlay when the player ends the match. There's no fixed
/// round count and no escalating stakes — the player leaves whenever they want.
struct GameContainerView: View {
    @ObservedObject var game: GameModel
    var useTimer: Bool
    var debugAutoFillArrange: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            switch game.phase {
            case .arranging:
                if game.players.first?.arrangement == nil {
                    ArrangeView(game: game, useTimer: useTimer, debugAutoFill: debugAutoFillArrange, onSubmitted: {})
                } else {
                    ResultsView(game: game, onNextRound: { game.startRound() }, onEndMatch: { game.endMatch() })
                }
            case .resolved:
                ResultsView(game: game, onNextRound: { game.startRound() }, onEndMatch: { game.endMatch() })
            }

            if game.matchOver {
                matchOverOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var matchOverOverlay: some View {
        VStack(spacing: 16) {
            Text(L("game.matchOver")).font(.title.bold()).foregroundStyle(.yellow)
            ForEach(0..<game.playerCount, id: \.self) { i in
                Text("\(game.displayName(i)): \(game.matchScores[safe: i] ?? 0)")
                    .foregroundStyle(i == 0 ? .yellow : .white)
            }
            Button(L("game.done")) { dismiss() }
                .buttonStyle(.borderedProminent).tint(.green)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(40)
    }
}
