import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    let userId: String
    var isSelf: Bool = false

    @State private var profile: Profile?
    @State private var lists: [TopTen] = []
    @State private var followers = 0
    @State private var following = 0
    @State private var isFollowing = false
    @State private var showEdit = false
    @State private var error: String?

    var body: some View {
        ZStack {
            AtmosphereBackground()

            List {
                Section {
                    HStack(spacing: 16) {
                        avatar
                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile?.fullName ?? "…")
                                .font(.custom("AvenirNext-Bold", size: 22))
                                .foregroundStyle(Theme.ink)
                            Text("@\(profile?.username ?? "")")
                                .font(.custom("AvenirNext-Medium", size: 14))
                                .foregroundStyle(Theme.mutedText)
                            HStack(spacing: 16) {
                                Text("\(followers) followers")
                                Text("\(following) following")
                            }
                            .font(.custom("AvenirNext-Medium", size: 13))
                            .foregroundStyle(Theme.deepTeal)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.7))

                    if isSelf {
                        Button("Edit profile") { showEdit = true }
                            .font(.custom("AvenirNext-DemiBold", size: 15))
                            .listRowBackground(Color.white.opacity(0.7))

                        Button("Sign out", role: .destructive) {
                            session.signOut()
                        }
                        .listRowBackground(Color.white.opacity(0.7))
                    } else if session.auth.uid != userId {
                        Button(isFollowing ? "Following" : "Follow") {
                            Task { await toggleFollow() }
                        }
                        .font(.custom("AvenirNext-DemiBold", size: 15))
                        .listRowBackground(Color.white.opacity(0.7))
                    }
                }

                Section("Top 10s") {
                    if lists.isEmpty {
                        Text("No lists to show")
                            .foregroundStyle(Theme.mutedText)
                            .listRowBackground(Color.white.opacity(0.65))
                    } else {
                        ForEach(lists) { list in
                            NavigationLink(value: list.id) {
                                TopTenRow(list: list)
                            }
                            .listRowBackground(Color.white.opacity(0.65))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(isSelf ? "Profile" : (profile?.username ?? "Profile"))
        .navigationDestination(for: UUID.self) { id in
            TopTenDetailView(listId: id)
        }
        .sheet(isPresented: $showEdit) {
            EditProfileView(profile: profile) { updated in
                profile = updated
                session.profile = updated
            }
        }
        .task { await load() }
    }

    private var avatar: some View {
        Group {
            if let urlString = profile?.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Theme.deepTeal
                }
            } else {
                Theme.deepTeal
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.amber, lineWidth: 2))
    }

    private func load() async {
        profile = try? await session.profiles.fetchProfile(id: userId)
        lists = (try? await session.lists.fetchMyLists(ownerId: userId)) ?? []
        followers = (try? await session.profiles.followerCount(for: userId)) ?? 0
        following = (try? await session.profiles.followingCount(for: userId)) ?? 0
        if let uid = session.auth.uid, uid != userId {
            isFollowing = (try? await session.profiles.isFollowing(followerId: uid, followingId: userId)) ?? false
        }
    }

    private func toggleFollow() async {
        guard let uid = session.auth.uid else { return }
        do {
            if isFollowing {
                try await session.profiles.unfollow(followerId: uid, followingId: userId)
                isFollowing = false
                followers = max(0, followers - 1)
            } else {
                try await session.profiles.follow(followerId: uid, followingId: userId)
                isFollowing = true
                followers += 1
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let profile: Profile?
    var onSave: (Profile) -> Void

    @State private var fullName = ""
    @State private var username = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var error: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text("Change photo")
                    }
                    TextField("Full name", text: $fullName)
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                }
                if let error {
                    Section { ErrorBanner(message: error) }
                }
            }
            .navigationTitle("Edit profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
            .onAppear {
                fullName = profile?.fullName ?? ""
                username = profile?.username ?? ""
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        avatarImage = image
                    }
                }
            }
        }
    }

    private func save() async {
        guard let uid = session.auth.uid else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            var avatarURL = profile?.avatarUrl
            if let avatarImage {
                avatarURL = try await session.profiles.uploadAvatar(userId: uid, image: avatarImage)
            }
            let updated = try await session.profiles.upsertProfile(
                id: uid,
                username: username,
                fullName: fullName,
                avatarUrl: avatarURL
            )
            onSave(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
