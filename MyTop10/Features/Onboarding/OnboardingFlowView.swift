import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            switch session.onboardingStep {
            case .welcome:
                WelcomeView()
            case .phone:
                PhoneEntryView()
            case .otp:
                OTPVerifyView()
            case .profile:
                ProfileSetupView()
            case .permissions, .complete:
                PermissionsView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: session.onboardingStep)
    }
}
