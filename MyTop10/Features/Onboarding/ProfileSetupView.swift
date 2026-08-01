import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject private var session: AppSession

    @State private var fullName = ""
    @State private var username = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var error: String?
    @State private var isSaving = false

    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && username.count >= 3
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

                    Text("Add a face, your name, and a username so friends can find your Top 10s.")
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

        isSaving = true
        defer { isSaving = false }

        do {
            let available = try await session.profiles.isUsernameAvailable(username, excluding: uid)
            guard available else { throw AuthError.usernameTaken }

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
