import SwiftUI

struct MyListsView: View {
    @EnvironmentObject private var session: AppSession
    @State private var lists: [TopTen] = []
    @State private var isLoading = false
    @State private var showProfile = false
    @State private var error: String?
    @Binding var selectedTab: MainTab

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                if isLoading && lists.isEmpty {
                    ProgressView()
                } else if lists.isEmpty {
                    EmptyStateView(
                        title: "No Top 10s yet",
                        message: "Build your first list — restaurants, albums, trails, anything.",
                        actionTitle: "Create a Top 10",
                        action: { selectedTab = .create }
                    )
                } else {
                    List {
                        ForEach(lists) { list in
                            NavigationLink(value: list.id) {
                                TopTenRow(list: list)
                            }
                            .listRowBackground(Color.white.opacity(0.65))
                        }
                        .onDelete(perform: delete)

                        Section {
                            BannerAdView(unitID: AppConfig.admobBannerUnitID)
                                .frame(height: 50)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("My Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileBubble(profile: session.profile) {
                        showProfile = true
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                TopTenDetailView(listId: id)
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView(userId: session.auth.uid ?? "", isSelf: true)
                }
            }
            .task { await load() }
            .alert("Error", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    private func load() async {
        guard let uid = session.auth.uid else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            lists = try await session.lists.fetchMyLists(ownerId: uid)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        Task {
            for index in offsets {
                try? await session.lists.deleteList(id: lists[index].id)
            }
            lists.remove(atOffsets: offsets)
        }
    }
}

struct TopTenRow: View {
    let list: TopTen

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(list.title)
                .font(.custom("AvenirNext-DemiBold", size: 17))
                .foregroundStyle(Theme.ink)
            HStack {
                Text(list.visibility.label)
                    .font(.custom("AvenirNext-Medium", size: 12))
                    .foregroundStyle(Theme.mutedText)
                Spacer()
                Label("\(list.score)", systemImage: "arrow.up.arrow.down")
                    .font(.custom("AvenirNext-Medium", size: 12))
                    .foregroundStyle(Theme.lagoon)
            }
        }
        .padding(.vertical, 4)
    }
}
