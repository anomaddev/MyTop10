import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            switch session.route {
            case .loading:
                ZStack {
                    Theme.heroGradient.ignoresSafeArea()
                    VStack(spacing: 16) {
                        BrandTitle(size: 44)
                        ProgressView()
                            .tint(Theme.amber)
                    }
                }
            case .onboarding:
                OnboardingFlowView()
            case .signedIn:
                MainTabView()
            }
        }
        .task {
            await session.bootstrap()
        }
        .animation(.easeInOut(duration: 0.35), value: session.route)
    }
}
