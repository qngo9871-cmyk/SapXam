import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        #if DEBUG
        if let lang = ProcessInfo.processInfo.environment["SX_LANG"], let l = AppLanguage(rawValue: lang) {
            LocalizationManager.shared.setLanguage(l)
        }
        if let capture = ProcessInfo.processInfo.environment["SX_CAPTURE"] {
            if capture.hasPrefix("onboarding") {
                let page = Int(capture.dropFirst("onboarding".count)) ?? 0
                return AnyView(OnboardingView(onFinished: {}, startPage: page).preferredColorScheme(.dark))
            }
            if capture == "upgrade" {
                return AnyView(UpgradeView().preferredColorScheme(.dark))
            }
            if capture == "rules" {
                return AnyView(RulesView().preferredColorScheme(.dark))
            }
            if capture == "arrange" || capture == "results" {
                let game = GameModel()
                game.startMatch(playerCount: 4, difficulty: .easy)
                if capture == "results", let human = game.players.first, human.arrangement == nil {
                    if let suggestion = game.suggestedArrangement() {
                        game.submitHumanArrangement(suggestion)
                    }
                }
                return AnyView(NavigationStack { GameContainerView(game: game, useTimer: false, debugAutoFillArrange: capture == "arrange") }.preferredColorScheme(.dark))
            }
        }
        if ProcessInfo.processInfo.environment["SX_SKIP_ONBOARDING"] != nil {
            return AnyView(HomeView())
        }
        #endif
        if !hasSeenOnboarding {
            return AnyView(OnboardingView(onFinished: { hasSeenOnboarding = true }))
        }
        return AnyView(HomeView())
    }
}

#Preview { ContentView() }
