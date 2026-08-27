import Foundation
import SwiftUI

@MainActor
final class AppSession: ObservableObject {
    enum Route: Equatable {
        case loading
        case onboarding(OnboardingStep)
        case signedIn
    }

    @Published var route: Route = .loading
    @Published var profile: Profile?
    @Published var onboardingStep: OnboardingStep = .welcome

    let auth = AuthService()
    let profiles = ProfileService()
    let lists = TopTenService()
    let location = LocationPermissionService()
    let notifications = NotificationPermissionService()

    private let defaults = UserDefaults.standard
    private let onboardingKey = "mytop10.onboarding.complete"

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: onboardingKey) }
        set { defaults.set(newValue, forKey: onboardingKey) }
    }

    func bootstrap() async {
        route = .loading
        if auth.isSignedIn {
            await refreshProfile()
            if profile == nil || !hasCompletedOnboarding {
                onboardingStep = profile == nil ? .profile : .permissions
                route = .onboarding(onboardingStep)
            } else {
                route = .signedIn
            }
        } else {
            onboardingStep = .welcome
            route = .onboarding(.welcome)
        }
    }

    func refreshProfile() async {
        guard let uid = auth.uid else {
            profile = nil
            return
        }
        do {
            profile = try await profiles.fetchProfile(id: uid)
        } catch {
            // Keep prior profile if offline / not yet configured.
        }
    }

    func advanceOnboarding(to step: OnboardingStep) {
        onboardingStep = step
        route = .onboarding(step)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        route = .signedIn
    }

    func signOut() {
        try? auth.signOut()
        profile = nil
        hasCompletedOnboarding = false
        onboardingStep = .welcome
        route = .onboarding(.welcome)
    }
}
