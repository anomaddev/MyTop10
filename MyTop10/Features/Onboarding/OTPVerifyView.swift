import SwiftUI

struct OTPVerifyView: View {
    @EnvironmentObject private var session: AppSession
    @State private var code = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            AtmosphereBackground()

            VStack(alignment: .leading, spacing: 24) {
                Button {
                    session.advanceOnboarding(to: .phone)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }

                Text("Enter the code")
                    .font(.custom("AvenirNext-Bold", size: 28))
                    .foregroundStyle(Theme.ink)

                Text("We sent a 6-digit code to \(session.auth.pendingPhoneE164 ?? "your phone").")
                    .font(.custom("AvenirNext-Regular", size: 16))
                    .foregroundStyle(Theme.mutedText)

                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .font(.custom("AvenirNext-Bold", size: 32))
                    .tracking(8)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($focused)
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                        if code.count == 6 {
                            Task { await verify() }
                        }
                    }

                if let error {
                    ErrorBanner(message: error)
                }

                Button("Verify") {
                    Task { await verify() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(code.count < 6 || session.auth.isLoading)

                Button("Resend code") {
                    Task {
                        if let phone = session.auth.pendingPhoneE164 {
                            try? await session.auth.sendOTP(to: phone)
                        }
                    }
                }
                .font(.custom("AvenirNext-Medium", size: 15))
                .foregroundStyle(Theme.deepTeal)

                Spacer()
            }
            .padding(24)
        }
        .onAppear { focused = true }
    }

    private func verify() async {
        error = nil
        do {
            try await session.auth.verifyOTP(code)
            await session.refreshProfile()
            if session.profile == nil {
                session.advanceOnboarding(to: .profile)
            } else {
                session.advanceOnboarding(to: .permissions)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
