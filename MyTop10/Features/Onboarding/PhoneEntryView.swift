import SwiftUI

struct PhoneEntryView: View {
    @EnvironmentObject private var session: AppSession
    @State private var phone = ""
    @State private var isSignInMode = false
    @State private var password = ""
    @State private var error: String?
    @State private var appear = false

    var body: some View {
        ZStack {
            AtmosphereBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Button {
                        session.advanceOnboarding(to: .welcome)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.top, 8)

                    BrandTitle(size: 36, light: false)
                        .opacity(appear ? 1 : 0)

                    Text(isSignInMode ? "Welcome back" : "What’s your number?")
                        .font(.custom("AvenirNext-Bold", size: 28))
                        .foregroundStyle(Theme.ink)

                    Text(isSignInMode
                         ? "Sign in with the phone and password you used to join."
                         : "We’ll text a code to verify it’s you. Standard SMS rates may apply.")
                        .font(.custom("AvenirNext-Regular", size: 16))
                        .foregroundStyle(Theme.mutedText)

                    AppTextField(
                        title: "Phone number",
                        text: $phone,
                        keyboard: .phonePad,
                        textContentType: .telephoneNumber,
                        autocapitalization: .never
                    )

                    if isSignInMode {
                        AppTextField(
                            title: "Password",
                            text: $password,
                            textContentType: .password,
                            isSecure: true
                        )
                    }

                    if let error {
                        ErrorBanner(message: error)
                    }

                    Button(isSignInMode ? "Sign In" : "Send Code") {
                        Task { await continueTapped() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(session.auth.isLoading)

                    Button(isSignInMode ? "New here? Create an account" : "Already have an account? Sign in") {
                        withAnimation { isSignInMode.toggle() }
                    }
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .foregroundStyle(Theme.deepTeal)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appear = true }
        }
    }

    private func continueTapped() async {
        error = nil
        do {
            if isSignInMode {
                try await session.auth.signIn(phone: phone, password: password)
                await session.refreshProfile()
                if session.profile == nil {
                    session.advanceOnboarding(to: .profile)
                } else {
                    session.completeOnboarding()
                }
            } else {
                try await session.auth.sendOTP(to: phone)
                session.advanceOnboarding(to: .otp)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
