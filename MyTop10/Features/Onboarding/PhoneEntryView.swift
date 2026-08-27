import SwiftUI

struct PhoneEntryView: View {
    @EnvironmentObject private var session: AppSession
    @State private var phone = ""
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

                    Text("What’s your number?")
                        .font(.custom("AvenirNext-Bold", size: 28))
                        .foregroundStyle(Theme.ink)

                    Text("We’ll text a one-time code to sign you in. No password needed — your phone is your key. Standard SMS rates may apply.")
                        .font(.custom("AvenirNext-Regular", size: 16))
                        .foregroundStyle(Theme.mutedText)

                    AppTextField(
                        title: "Phone number",
                        text: $phone,
                        keyboard: .phonePad,
                        textContentType: .telephoneNumber,
                        autocapitalization: .never
                    )

                    if let error {
                        ErrorBanner(message: error)
                    }

                    Button(session.auth.isLoading ? "Sending…" : "Send Code") {
                        Task { await continueTapped() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(session.auth.isLoading)
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
            try await session.auth.sendOTP(to: phone)
            session.advanceOnboarding(to: .otp)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
