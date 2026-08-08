import SwiftUI

struct HomeView: View {
    @EnvironmentObject var loc: LocalizationManager
    @StateObject private var purchases = PurchaseManager.shared
    @State private var showGame = false
    @State private var showRules = false
    @State private var showUpgrade = false
    @State private var showOnboarding = false
    @State private var selectedDifficulty: AIDifficulty = .easy
    @State private var selectedPlayerCount: Int = 4
    @State private var useTimer: Bool = false
    @State private var game = GameModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.04, green: 0.12, blue: 0.28), .black],
                                startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 12)

                        VStack(spacing: 6) {
                            Text("🀄️").font(.system(size: 52))
                            Text(L("home.title")).font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text(L("home.subtitle")).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center).padding(.horizontal, 20)
                        }

                        VStack(spacing: 10) {
                            Text(L("home.players")).font(.caption).foregroundStyle(.white.opacity(0.6))
                            Picker("", selection: $selectedPlayerCount) {
                                ForEach(2...4, id: \.self) { n in
                                    Text("\(n)").tag(n)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 220)
                        }

                        VStack(spacing: 10) {
                            Text(L("home.difficulty")).font(.caption).foregroundStyle(.white.opacity(0.6))
                            Picker("", selection: $selectedDifficulty) {
                                ForEach(AIDifficulty.allCases) { d in
                                    Text(L(d.titleKey) + (d == .hard && !purchases.isPro ? " 🔒" : "")).tag(d)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 320)
                        }

                        Toggle(isOn: $useTimer) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("home.timer.title")).font(.subheadline).foregroundStyle(.white)
                                Text(L("home.timer.subtitle")).font(.caption2).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(.blue)
                        .frame(maxWidth: 320)
                        .padding(.horizontal, 20)

                        VStack(spacing: 14) {
                            Button {
                                if selectedDifficulty == .hard && !purchases.isPro {
                                    showUpgrade = true
                                } else {
                                    game = GameModel()
                                    game.startMatch(playerCount: selectedPlayerCount, difficulty: selectedDifficulty)
                                    showGame = true
                                }
                            } label: {
                                Text(L("home.play")).font(.title3.bold()).frame(maxWidth: 280).padding()
                            }
                            .buttonStyle(.borderedProminent).tint(.blue)

                            HStack(spacing: 20) {
                                Button { showOnboarding = true } label: {
                                    Text(L("home.howtoplay")).foregroundStyle(.white.opacity(0.85))
                                }
                                Button { showRules = true } label: {
                                    Text(L("home.rules")).foregroundStyle(.white.opacity(0.85))
                                }
                            }

                            if !purchases.isPro {
                                Button { showUpgrade = true } label: {
                                    Text(L("home.upgrade")).font(.footnote).foregroundStyle(.yellow)
                                }
                            }
                        }

                        VStack(spacing: 4) {
                            Text(L("home.noStakes")).font(.caption2).foregroundStyle(.white.opacity(0.45))
                                .multilineTextAlignment(.center).padding(.horizontal, 30)
                        }

                        Spacer(minLength: 12)

                        Picker("", selection: $loc.language) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                        .padding(.bottom, 24)
                    }
                    .padding()
                }
            }
            .navigationDestination(isPresented: $showGame) {
                GameContainerView(game: game, useTimer: useTimer)
            }
            .sheet(isPresented: $showRules) { RulesView() }
            .sheet(isPresented: $showUpgrade) { UpgradeView() }
            .sheet(isPresented: $showOnboarding) { OnboardingView(onFinished: { showOnboarding = false }) }
            .task { await purchases.loadProduct() }
        }
    }
}

#Preview { HomeView().environmentObject(LocalizationManager.shared) }
