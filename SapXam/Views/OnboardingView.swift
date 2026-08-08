import SwiftUI

/// First-launch walkthrough. Includes worked examples for the special "tới trắng" hands and
/// the scoop bonus — these are consistently the most confusing part for newcomers to this
/// game family, per competitor review research (see CLAUDE.md), so they get an actual
/// example hand shown, not just a text description.
struct OnboardingView: View {
    var onFinished: () -> Void
    var startPage: Int = 0

    @State private var page = 0
    private let pageCount = 4

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.12, blue: 0.28), .black],
                            startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 8)

                Group {
                    switch page {
                    case 0: goalPage
                    case 1: specialHandPage
                    case 2: scoopPage
                    default: noStakesPage
                    }
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    ForEach(0..<pageCount, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.white : Color.white.opacity(0.25))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer(minLength: 8)

                Button(action: advance) {
                    Text(page == pageCount - 1 ? L("onboarding.begin") : L("onboarding.next"))
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .animation(.easeInOut, value: page)
        .onAppear { page = startPage }
    }

    private var goalPage: some View {
        VStack(spacing: 20) {
            Text("🀄️").font(.system(size: 44))
            Text(L("onboarding.goal.title")).font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(.white).multilineTextAlignment(.center)
            Text(L("onboarding.goal.body")).font(.body).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center).padding(.horizontal, 24)

            VStack(spacing: 6) {
                exampleRow(L("arrange.back"), "5")
                exampleRow(L("arrange.middle"), "5")
                exampleRow(L("arrange.front"), "3")
            }
            .padding(14)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            Text(L("onboarding.goal.foul")).font(.caption).foregroundStyle(.orange.opacity(0.9))
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }

    private func exampleRow(_ label: String, _ count: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.white).font(.subheadline.bold())
            Spacer()
            Text(count + " " + L("onboarding.cards")).foregroundStyle(.white.opacity(0.6)).font(.caption)
        }
    }

    /// Worked example: Sảnh Rồng, a 13-card straight in mixed suits — the run every player
    /// eventually asks "wait, what actually counts?" about.
    private var specialHandPage: some View {
        let exampleHand: [Card] = [
            Card(rank: .two, suit: .spades), Card(rank: .three, suit: .hearts), Card(rank: .four, suit: .clubs),
            Card(rank: .five, suit: .diamonds), Card(rank: .six, suit: .spades), Card(rank: .seven, suit: .hearts),
            Card(rank: .eight, suit: .clubs), Card(rank: .nine, suit: .diamonds), Card(rank: .ten, suit: .spades),
            Card(rank: .jack, suit: .hearts), Card(rank: .queen, suit: .clubs), Card(rank: .king, suit: .diamonds),
            Card(rank: .ace, suit: .spades),
        ]
        return VStack(spacing: 16) {
            Text(L("onboarding.special.title")).font(.system(.title, design: .rounded).bold())
                .foregroundStyle(.white).multilineTextAlignment(.center)
            Text(L("onboarding.special.body")).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center).padding(.horizontal, 20)

            VStack(spacing: 6) {
                Text(L("special.sanhRong")).font(.headline).foregroundStyle(.yellow)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -10) {
                        ForEach(exampleHand) { CardView(card: $0, width: 30) }
                    }
                }
                Text(String(format: L("onboarding.special.example"), 12))
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)

            Text(L("onboarding.special.note")).font(.caption2).foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }

    /// Worked example: winning all 3 sub-hands against one opponent triggers a scoop bonus.
    private var scoopPage: some View {
        VStack(spacing: 16) {
            Text(L("onboarding.scoop.title")).font(.system(.title, design: .rounded).bold())
                .foregroundStyle(.white).multilineTextAlignment(.center)
            Text(L("onboarding.scoop.body")).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center).padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                scoopLine(L("arrange.back"), L("onboarding.scoop.win"), "+1")
                scoopLine(L("arrange.middle"), L("onboarding.scoop.win"), "+1")
                scoopLine(L("arrange.front"), L("onboarding.scoop.win"), "+1")
                Divider().overlay(Color.white.opacity(0.2))
                scoopLine(L("onboarding.scoop.bonusLabel"), "", "+3")
                Divider().overlay(Color.white.opacity(0.2))
                scoopLine(L("onboarding.scoop.totalLabel"), "", "+6")
            }
            .padding(14)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
        }
    }

    private func scoopLine(_ label: String, _ sub: String, _ value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).foregroundStyle(.white).font(.subheadline.bold())
                if !sub.isEmpty { Text(sub).foregroundStyle(.white.opacity(0.5)).font(.caption2) }
            }
            Spacer()
            Text(value).foregroundStyle(.green).font(.subheadline.bold().monospacedDigit())
        }
    }

    private var noStakesPage: some View {
        VStack(spacing: 20) {
            Text("🕊️").font(.system(size: 44))
            Text(L("onboarding.stakes.title")).font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(.white).multilineTextAlignment(.center)
            Text(L("onboarding.stakes.body")).font(.body).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center).padding(.horizontal, 24)
        }
    }

    private func advance() {
        if page < pageCount - 1 {
            page += 1
        } else {
            onFinished()
        }
    }
}

#Preview { OnboardingView(onFinished: {}) }
