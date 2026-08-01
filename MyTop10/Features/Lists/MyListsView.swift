import SwiftUI

struct MyListsView: View {
    @EnvironmentObject private var session: AppSession
    @State private var lists: [TopTen] = []
    @State private var isLoading = false
    @State private var isReordering = false
    @State private var showProfile = false
    @State private var editingList: TopTen?
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
                        Section {
                            Text(isReordering
                                 ? "Drag the handles to reorder your lists."
                                 : "Swipe left to edit or delete. Tap Reorder to rearrange.")
                                .font(.custom("AvenirNext-Regular", size: 13))
                                .foregroundStyle(Theme.mutedText)
                                .listRowBackground(Color.clear)
                        }

                        ForEach(lists) { list in
                            NavigationLink(value: list.id) {
                                TopTenRow(list: list)
                            }
                            .listRowBackground(Color.white.opacity(0.65))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await delete(list) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingList = list
                                } label: {
                                    Label("Edit", systemImage: "slider.horizontal.3")
                                }
                                .tint(Theme.deepTeal)
                            }
                        }
                        .onMove(perform: isReordering ? moveLists : nil)
                        .onDelete(perform: isReordering ? nil : deleteOffsets)

                        Section {
                            BannerAdView(unitID: AppConfig.admobBannerUnitID)
                                .frame(height: 50)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(isReordering ? .active : .inactive))
                    .refreshable { await load() }
                }
            }
            .navigationTitle("My Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !lists.isEmpty {
                        Button(isReordering ? "Done" : "Reorder") {
                            Task { await toggleReorder() }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            selectedTab = .create
                        } label: {
                            Image(systemName: "plus")
                        }
                        ProfileBubble(profile: session.profile) {
                            showProfile = true
                        }
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
            .sheet(item: $editingList) { list in
                ListSettingsSheet(
                    list: list,
                    onSaved: { updated in
                        if let index = lists.firstIndex(where: { $0.id == updated.id }) {
                            lists[index] = updated
                        }
                    },
                    onDeleted: {
                        lists.removeAll { $0.id == list.id }
                    }
                )
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

    private func deleteOffsets(at offsets: IndexSet) {
        Task {
            for index in offsets {
                await delete(lists[index])
            }
        }
    }

    private func delete(_ list: TopTen) async {
        do {
            try await session.lists.deleteList(id: list.id)
            lists.removeAll { $0.id == list.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func moveLists(from source: IndexSet, to destination: Int) {
        lists.move(fromOffsets: source, toOffset: destination)
    }

    private func toggleReorder() async {
        if isReordering {
            do {
                try await session.lists.reorderLists(lists)
            } catch {
                self.error = error.localizedDescription
                await load()
            }
        }
        isReordering.toggle()
    }
}

struct TopTenRow: View {
    let list: TopTen

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(list.title)
                .font(.custom("AvenirNext-DemiBold", size: 17))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 12) {
                Label(list.visibility.label, systemImage: list.visibility.systemImage)
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
