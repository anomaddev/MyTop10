import SwiftUI

struct TopTenDetailView: View {
    @EnvironmentObject private var session: AppSession
    let listId: UUID

    @State private var list: TopTen?
    @State private var items: [TopTenItem] = []
    @State private var userVote = 0
    @State private var isBookmarked = false
    @State private var isEditing = false
    @State private var showMap = false
    @State private var error: String?

    private var isOwner: Bool {
        list?.ownerId == session.auth.uid
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            if let list {
                List {
                    Section {
                        Text(list.title)
                            .font(.custom("AvenirNext-Bold", size: 26))
                            .foregroundStyle(Theme.ink)
                            .listRowBackground(Color.clear)

                        VoteBookmarkBar(
                            score: list.score,
                            userVote: userVote,
                            isBookmarked: isBookmarked,
                            onUp: { Task { await vote(1) } },
                            onDown: { Task { await vote(-1) } },
                            onBookmark: { Task { await toggleBookmark() } }
                        )
                        .listRowBackground(Color.white.opacity(0.65))
                    }

                    Section("The Ten") {
                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(item.rank)")
                                    .font(.custom("AvenirNext-Heavy", size: 22))
                                    .foregroundStyle(Theme.amber)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.custom("AvenirNext-DemiBold", size: 16))
                                    if let note = item.note, !note.isEmpty {
                                        Text(note)
                                            .font(.custom("AvenirNext-Regular", size: 13))
                                            .foregroundStyle(Theme.mutedText)
                                    }
                                    if item.hasLocation {
                                        Label(item.placeName ?? "Pinned place", systemImage: "mappin.and.ellipse")
                                            .font(.custom("AvenirNext-Medium", size: 12))
                                            .foregroundStyle(Theme.deepTeal)
                                    }
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.65))
                        }
                        .onMove(perform: isOwner && isEditing ? move : nil)
                    }

                    if items.contains(where: \.hasLocation) {
                        Section {
                            Button {
                                showMap = true
                            } label: {
                                Label("View on map", systemImage: "map")
                                    .font(.custom("AvenirNext-DemiBold", size: 16))
                            }
                            .listRowBackground(Color.white.opacity(0.65))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        Task { await toggleEdit() }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let list {
                    ShareLink(item: "Check out my Top 10: \(list.title) on MyTop10")
                }
            }
        }
        .sheet(isPresented: $showMap) {
            ListMapView(items: items.filter(\.hasLocation))
        }
        .task { await load() }
    }

    private func load() async {
        do {
            list = try await session.lists.fetchList(id: listId)
            items = try await session.lists.fetchItems(for: listId)
            if let uid = session.auth.uid {
                userVote = try await session.lists.currentVote(userId: uid, topTenId: listId)
                isBookmarked = try await session.lists.isBookmarked(userId: uid, topTenId: listId)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func vote(_ value: Int) async {
        guard let uid = session.auth.uid else { return }
        let next = userVote == value ? 0 : value
        do {
            try await session.lists.setVote(userId: uid, topTenId: listId, value: next)
            userVote = next
            list = try await session.lists.fetchList(id: listId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func toggleBookmark() async {
        guard let uid = session.auth.uid else { return }
        do {
            try await session.lists.setBookmark(userId: uid, topTenId: listId, bookmarked: !isBookmarked)
            isBookmarked.toggle()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        for index in items.indices {
            items[index].rank = index + 1
        }
    }

    private func toggleEdit() async {
        if isEditing {
            do {
                try await session.lists.replaceItems(topTenId: listId, items: items)
            } catch {
                self.error = error.localizedDescription
            }
        }
        isEditing.toggle()
    }
}
