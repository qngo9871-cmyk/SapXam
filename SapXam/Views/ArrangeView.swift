import SwiftUI

/// Main gameplay screen: arrange your 13 dealt cards into front (3) / middle (5) / back (5).
/// Tap a card to select it, then tap a zone to place it there; tap a placed card to send it
/// back to the tray. "Auto-Arrange" fills in a non-fouling suggestion (Hard-tier search) you
/// can still hand-tweak before submitting.
///
/// Untimed by default — a deliberate differentiator (see onboarding/CLAUDE.md): competitor
/// apps are reported to impose an "almost impossible" arrangement timer for newcomers. When
/// `useTimer` is on this screen uses a generous 90-second countdown instead of a harsh one.
struct ArrangeView: View {
    @ObservedObject var game: GameModel
    var useTimer: Bool = false
    var debugAutoFill: Bool = false
    var onSubmitted: () -> Void

    @State private var front: [Card] = []
    @State private var middle: [Card] = []
    @State private var back: [Card] = []
    @State private var selectedID: UUID?
    @State private var secondsRemaining: Int = 90
    @State private var timerTask: Task<Void, Never>?

    private enum Zone { case front, middle, back }

    private var tray: [Card] {
        let placed = Set((front + middle + back).map(\.id))
        return game.players.first?.hand.filter { !placed.contains($0.id) } ?? []
    }

    private var isComplete: Bool { front.count == 3 && middle.count == 5 && back.count == 5 }

    private var previewArrangement: Arrangement { Arrangement(front: front, middle: middle, back: back) }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.1, blue: 0.22).ignoresSafeArea()

            VStack(spacing: 10) {
                header

                ScrollView {
                    VStack(spacing: 10) {
                        zoneRow(title: L("arrange.back"), cards: back, capacity: 5, zone: .back)
                        zoneRow(title: L("arrange.middle"), cards: middle, capacity: 5, zone: .middle)
                        zoneRow(title: L("arrange.front"), cards: front, capacity: 3, zone: .front)
                    }
                    .padding(.horizontal)
                }

                if isComplete && previewArrangement.isFouled {
                    Text(L("arrange.fouled"))
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                trayArea
                actionButtons
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: setup)
        .onDisappear { timerTask?.cancel() }
    }

    private func setup() {
        front = []; middle = []; back = []; selectedID = nil
        if debugAutoFill { autoArrange() }
        if useTimer {
            secondsRemaining = 90
            timerTask?.cancel()
            timerTask = Task {
                while secondsRemaining > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                    secondsRemaining -= 1
                }
                if !isComplete || previewArrangement.isFouled {
                    autoArrange()
                }
                submit()
            }
        }
    }

    private var header: some View {
        HStack {
            Text(String(format: L("game.round"), game.roundNumber))
                .font(.caption).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(L("arrange.title")).font(.headline).foregroundStyle(.white)
            Spacer()
            if useTimer {
                Text("⏱ \(secondsRemaining)s")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(secondsRemaining <= 15 ? .red : .white.opacity(0.7))
            } else {
                Text(L("arrange.practice"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal).padding(.top, 8)
    }

    private func zoneRow(title: String, cards: [Card], capacity: Int, zone: Zone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(title) (\(cards.count)/\(capacity))")
                    .font(.caption.bold()).foregroundStyle(.white.opacity(0.85))
                Spacer()
                if let label = handLabel(for: cards) {
                    Text(label).font(.caption2.bold()).foregroundStyle(.yellow)
                }
            }
            HStack(spacing: -8) {
                ForEach(cards) { card in
                    CardView(card: card, width: 40)
                        .onTapGesture { removeFromZone(card) }
                }
                if cards.count < capacity {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 40, height: 58)
                }
            }
            .frame(minHeight: 60)
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture { placeSelected(in: zone) }
    }

    private func handLabel(for cards: [Card]) -> String? {
        if cards.count == 3 { return L(HandEvaluator.evaluate3(cards).category.labelKey) }
        if cards.count == 5 { return L(HandEvaluator.evaluate5(cards).category.labelKey) }
        return nil
    }

    private var trayArea: some View {
        VStack(spacing: 6) {
            Text(L("arrange.tray")).font(.caption2).foregroundStyle(.white.opacity(0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -8) {
                    ForEach(tray) { card in
                        CardView(card: card, selected: selectedID == card.id, width: 44)
                            .onTapGesture { toggleSelect(card) }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 70)
        }
        .padding(.top, 4)
        .background(Color.black.opacity(0.2))
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button(L("arrange.auto")) { autoArrange() }
                .buttonStyle(.bordered).tint(.blue)
            Button(L("arrange.submit")) { submit() }
                .buttonStyle(.borderedProminent).tint(.green)
                .disabled(!isComplete || previewArrangement.isFouled)
        }
        .padding(.bottom, 14)
    }

    private func toggleSelect(_ card: Card) {
        selectedID = (selectedID == card.id) ? nil : card.id
    }

    private func placeSelected(in zone: Zone) {
        guard let id = selectedID, let card = tray.first(where: { $0.id == id }) else { return }
        switch zone {
        case .front: guard front.count < 3 else { return }; front.append(card)
        case .middle: guard middle.count < 5 else { return }; middle.append(card)
        case .back: guard back.count < 5 else { return }; back.append(card)
        }
        selectedID = nil
    }

    private func removeFromZone(_ card: Card) {
        front.removeAll { $0.id == card.id }
        middle.removeAll { $0.id == card.id }
        back.removeAll { $0.id == card.id }
    }

    private func autoArrange() {
        guard let suggestion = game.suggestedArrangement() else { return }
        front = suggestion.front
        middle = suggestion.middle
        back = suggestion.back
        selectedID = nil
    }

    private func submit() {
        timerTask?.cancel()
        guard isComplete else { return }
        game.submitHumanArrangement(previewArrangement)
        onSubmitted()
    }
}

#Preview {
    let g = GameModel()
    g.startMatch(playerCount: 4, difficulty: .easy)
    return NavigationStack { ArrangeView(game: g, onSubmitted: {}) }
}
