import SwiftUI

struct TopTenDetailView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let listId: UUID

    @State private var list: TopTen?
    @State private var items: [TopTenItem] = []
    @State private var userVote = 0
    @State private var isBookmarked = false
    @State private var isReordering = false
    @State private var showMap = false
    @State private var showSettings = false
    @State private var editorContext: ItemEditorContext?
    @State private var error: String?
    @State private var tipVisible = true

    private var isOwner: Bool {
        list?.ownerId == session.auth.uid
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            if let list {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(list.title)
                                .font(.custom("AvenirNext-Bold", size: 26))
                                .foregroundStyle(Theme.ink)
                            HStack(spacing: 8) {
                                Label(list.visibility.label, systemImage: list.visibility.systemImage)
                                if isOwner {
                                    Text("·")
                                    Text("Swipe items to edit or delete")
                                }
                            }
                            .font(.custom("AvenirNext-Medium", size: 12))
                            .foregroundStyle(Theme.mutedText)
                        }
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

                    if isOwner && tipVisible && !items.isEmpty {
                        Section {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "hand.draw.fill")
                                    .foregroundStyle(Theme.amber)
                                Text("Tip: tap an item to open notes, tags, and photos. Use Edit to drag-reorder ranks.")
                                    .font(.custom("AvenirNext-Regular", size: 13))
                                    .foregroundStyle(Theme.mutedText)
                                Spacer(minLength: 0)
                                Button {
                                    tipVisible = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Theme.mutedText)
                                }
                            }
                            .listRowBackground(Theme.amber.opacity(0.12))
                        }
                    }

                    Section {
                        ForEach(items) { item in
                            Button {
                                guard isOwner else { return }
                                editorContext = ItemEditorContext(item: item, rank: item.rank, isNew: false)
                            } label: {
                                TopTenItemRow(item: item)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.white.opacity(0.65))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if isOwner {
                                    Button(role: .destructive) {
                                        Task { await deleteItem(item) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        editorContext = ItemEditorContext(item: item, rank: item.rank, isNew: false)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(Theme.deepTeal)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if isOwner {
                                    Button {
                                        Task { await toggleFavorite(item) }
                                    } label: {
                                        Label(
                                            item.isFavorite ? "Unfavorite" : "Favorite",
                                            systemImage: item.isFavorite ? "heart.slash" : "heart"
                                        )
                                    }
                                    .tint(Theme.coral)
                                }
                            }
                        }
                        .onMove(perform: isOwner && isReordering ? move : nil)

                        if isOwner && items.count < 10 {
                            Button {
                                editorContext = ItemEditorContext(
                                    item: nil,
                                    rank: items.count + 1,
                                    isNew: true
                                )
                            } label: {
                                Label("Add item (#\(items.count + 1))", systemImage: "plus.circle.fill")
                                    .font(.custom("AvenirNext-DemiBold", size: 16))
                                    .foregroundStyle(Theme.deepTeal)
                            }
                            .listRowBackground(Color.white.opacity(0.55))
                        }
                    } header: {
                        HStack {
                            Text("The Ten")
                            Spacer()
                            Text("\(items.count)/10")
                                .foregroundStyle(Theme.mutedText)
                        }
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
                .environment(\.editMode, .constant(isReordering ? .active : .inactive))
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isReordering ? "Done" : "Reorder") {
                        Task { await toggleReorder() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
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
        .sheet(item: $editorContext) { context in
            ItemEditorView(
                listId: listId,
                rank: context.rank,
                existing: context.item,
                onSaved: { saved in
                    Task { await handleSaved(saved, isNew: context.isNew) }
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            if let list {
                ListSettingsSheet(
                    list: list,
                    onSaved: { updated in self.list = updated },
                    onDeleted: { dismiss() }
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
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

    private func handleSaved(_ saved: TopTenItem, isNew: Bool) async {
        if isNew {
            items.append(saved)
        } else if let index = items.firstIndex(where: { $0.id == saved.id }) {
            items[index] = saved
        }
        items.sort { $0.rank < $1.rank }
    }

    private func deleteItem(_ item: TopTenItem) async {
        do {
            try await session.lists.deleteItem(id: item.id)
            items.removeAll { $0.id == item.id }
            // Re-rank remaining
            for index in items.indices {
                items[index].rank = index + 1
            }
            items = try await session.lists.reorderItems(topTenId: listId, items: items)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func toggleFavorite(_ item: TopTenItem) async {
        guard var updated = items.first(where: { $0.id == item.id }) else { return }
        updated.isFavorite.toggle()
        do {
            let saved = try await session.lists.updateItem(updated)
            if let index = items.firstIndex(where: { $0.id == saved.id }) {
                items[index] = saved
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

    private func toggleReorder() async {
        if isReordering {
            do {
                items = try await session.lists.reorderItems(topTenId: listId, items: items)
            } catch {
                self.error = error.localizedDescription
            }
        }
        isReordering.toggle()
    }
}

private struct ItemEditorContext: Identifiable {
    let id = UUID()
    let item: TopTenItem?
    let rank: Int
    let isNew: Bool
}
