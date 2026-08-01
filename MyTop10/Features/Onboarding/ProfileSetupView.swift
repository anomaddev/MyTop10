import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject private var session: AppSession

    @State private var fullName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var error: String?
    @State private var isSaving = false

    private var requirements: [PasswordRequirement] {
        PasswordValidator.requirements(
            password: password,
            username: username,
            phone: session.auth.pendingPhoneE164 ?? session.auth.user?.phoneNumber ?? ""
        )
    }

    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && username.count >= 3
            && password == confirmPassword
            && PasswordValidator.isStrong(
                password,
                username: username,
                phone: session.auth.pendingPhoneE164 ?? ""
            )
            && !isSaving
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BrandTitle(size: 32, light: false)

                    Text("Make it yours")
                        .font(.custom("AvenirNext-Bold", size: 28))
                        .foregroundStyle(Theme.ink)

                    Text("Add a face, a name, and a strong password to lock in your account.")
                        .font(.custom("AvenirNext-Regular", size: 16))
                        .foregroundStyle(Theme.mutedText)

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            Circle()
                                .fill(Theme.deepTeal.opacity(0.15))
                                .frame(width: 110, height: 110)
                            if let avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 110)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Theme.deepTeal)
                            }
                        }
                        .overlay(Circle().strokeBorder(Theme.amber, lineWidth: 2))
                    }
                    .frame(maxWidth: .infinity)
                    .onChange(of: selectedItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                avatarImage = image
                            }
                        }
                    }

                    AppTextField(title: "Full name", text: $fullName, textContentType: .name)
                    AppTextField(
                        title: "Username",
                        text: $username,
                        textContentType: .username,
                        autocapitalization: .never
                    )
                    .onChange(of: username) { _, value in
                        username = value.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                    }
                    AppTextField(
                        title: "Password",
                        text: $password,
                        textContentType: .newPassword,
                        isSecure: true
                    )
                    PasswordRequirementsView(requirements: requirements)
                    AppTextField(
                        title: "Confirm password",
                        text: $confirmPassword,
                        textContentType: .newPassword,
                        isSecure: true
                    )

                    if password != confirmPassword && !confirmPassword.isEmpty {
                        Text("Passwords do not match")
                            .font(.custom("AvenirNext-Medium", size: 13))
                            .foregroundStyle(Theme.coral)
                    }

                    if let error {
                        ErrorBanner(message: error)
                    }

                    Button(isSaving ? "Saving…" : "Continue") {
                        Task { await save() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSubmit)
                }
                .padding(24)
            }
        }
    }

    private func save() async {
        error = nil
        guard let uid = session.auth.uid else {
            error = AuthError.notConfigured.localizedDescription
            return
        }
        guard password == confirmPassword else {
            error = AuthError.passwordMismatch.localizedDescription
            return
        }
        guard PasswordValidator.isStrong(password, username: username, phone: session.auth.pendingPhoneE164 ?? "") else {
            error = AuthError.weakPassword.localizedDescription
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let available = try await session.profiles.isUsernameAvailable(username, excluding: uid)
            guard available else { throw AuthError.usernameTaken }

            try await session.auth.linkPassword(password)

            var avatarURL: String?
            if let avatarImage {
                avatarURL = try await session.profiles.uploadAvatar(userId: uid, image: avatarImage)
            }

            session.profile = try await session.profiles.upsertProfile(
                id: uid,
                username: username,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarUrl: avatarURL
            )
            session.advanceOnboarding(to: .permissions)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
