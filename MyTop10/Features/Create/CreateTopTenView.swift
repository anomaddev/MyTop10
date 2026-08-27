import SwiftUI

struct CreateTopTenView: View {
    @EnvironmentObject private var session: AppSession
    @State private var title = ""
    @State private var categories: [Category] = []
    @State private var categoryId: UUID?
    @State private var visibility: ListVisibility = .public
    @State private var drafts: [ItemDraft] = [ItemDraft()]
    @State private var editingDraftID: UUID?
    @State private var error: String?
    @State private var isSaving = false
    @State private var showSuccess = false
    private let interstitial = InterstitialAdCoordinator()

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                Form {
                    Section {
                        Text("Start with a title, then flesh out each spot with notes, tags, and photos.")
                            .font(.custom("AvenirNext-Regular", size: 13))
                            .foregroundStyle(Theme.mutedText)
                    }

                    Section("List") {
                        TextField("Title", text: $title)
                        Picker("Category", selection: $categoryId) {
                            Text("None").tag(UUID?.none)
                            ForEach(categories) { cat in
                                Text(cat.name).tag(Optional(cat.id))
                            }
                        }
                        Picker("Visibility", selection: $visibility) {
                            ForEach(ListVisibility.allCases) { v in
                                Label(v.label, systemImage: v.systemImage).tag(v)
                            }
                        }
                    }

                    Section {
                        ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                            Button {
                                editingDraftID = draft.id
                            } label: {
                                CreateDraftRow(rank: index + 1, draft: draft)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    drafts.removeAll { $0.id == draft.id }
                                    if drafts.isEmpty { drafts = [ItemDraft()] }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove { source, dest in
                            drafts.move(fromOffsets: source, toOffset: dest)
                        }

                        if drafts.count < 10 {
                            Button {
                                let new = ItemDraft()
                                drafts.append(new)
                                editingDraftID = new.id
                            } label: {
                                Label("Add item", systemImage: "plus.circle.fill")
                                    .foregroundStyle(Theme.deepTeal)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Your Top 10")
                            Spacer()
                            Text("\(drafts.filter { !$0.title.isEmpty }.count)/10")
                        }
                    }

                    if let error {
                        Section {
                            ErrorBanner(message: error)
                        }
                    }

                    Section {
                        Button(isSaving ? "Saving…" : "Publish Top 10") {
                            Task { await save() }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Top 10")
            .toolbar { EditButton() }
            .task { categories = (try? await session.lists.fetchCategories()) ?? [] }
            .sheet(item: Binding(
                get: {
                    editingDraftID.flatMap { id in drafts.first { $0.id == id } }
                },
                set: { _ in editingDraftID = nil }
            )) { draft in
                DraftItemEditorSheet(draft: draft) { updated in
                    if let index = drafts.firstIndex(where: { $0.id == updated.id }) {
                        drafts[index] = updated
                    }
                }
            }
            .alert("Published", isPresented: $showSuccess) {
                Button("OK") {
                    interstitial.showIfReady()
                    reset()
                }
            } message: {
                Text("Your Top 10 is live. Open it anytime to edit ranks, notes, and photos.")
            }
        }
    }

    private func save() async {
        guard let uid = session.auth.uid else { return }
        isSaving = true
        defer { isSaving = false }
        error = nil
        let filled = drafts.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !filled.isEmpty else {
            error = "Add at least one item before publishing."
            return
        }
        do {
            _ = try await session.lists.createList(
                ownerId: uid,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryId: categoryId,
                visibility: visibility,
                drafts: filled
            )
            showSuccess = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func reset() {
        title = ""
        categoryId = nil
        visibility = .public
        drafts = [ItemDraft()]
    }
}

private struct CreateDraftRow: View {
    let rank: Int
    let draft: ItemDraft

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.custom("AvenirNext-Heavy", size: 22))
                .foregroundStyle(Theme.amber)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title.isEmpty ? "Tap to add details" : draft.title)
                    .font(.custom("AvenirNext-DemiBold", size: 16))
                    .foregroundStyle(draft.title.isEmpty ? Theme.mutedText : Theme.ink)
                HStack(spacing: 8) {
                    if !draft.note.isEmpty {
                        Image(systemName: "note.text")
                    }
                    if !draft.tags.isEmpty {
                        Image(systemName: "tag")
                    }
                    if !draft.photoUrls.isEmpty || !draft.localPhotos.isEmpty {
                        Image(systemName: "photo")
                    }
                    if draft.latitude != nil {
                        Image(systemName: "mappin")
                    }
                    if draft.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Theme.coral)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.lagoon)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mutedText)
        }
        .padding(.vertical, 4)
    }
}

private struct DraftItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: ItemDraft
    @State private var showMapPicker = false
    var onSave: (ItemDraft) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        AppTextField(title: "Title", text: $draft.title)

                        VStack(alignment: .leading, spacing: 8) {
                            FieldLabel(text: "Notes")
                            TextEditor(text: $draft.note)
                                .font(.custom("AvenirNext-Regular", size: 16))
                                .frame(minHeight: 100)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        TagEditor(tags: $draft.tags)
                        StarRatingControl(rating: $draft.rating)
                        PhotoStripEditor(remoteUrls: $draft.photoUrls, localPhotos: $draft.localPhotos)

                        Toggle("Favorite", isOn: $draft.isFavorite)
                            .tint(Theme.coral)

                        Toggle("Mark as visited", isOn: Binding(
                            get: { draft.visitedOn != nil },
                            set: { draft.visitedOn = $0 ? (draft.visitedOn ?? Date()) : nil }
                        ))
                        .tint(Theme.lagoon)

                        Button {
                            showMapPicker = true
                        } label: {
                            Label(
                                draft.latitude == nil ? "Pin a place" : (draft.placeName.isEmpty ? "Pinned" : draft.placeName),
                                systemImage: "mappin.and.ellipse"
                            )
                            .font(.custom("AvenirNext-DemiBold", size: 15))
                            .foregroundStyle(Theme.deepTeal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button("Save item") {
                            onSave(draft)
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Item details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showMapPicker) {
                LocationPickerView { name, coord, address in
                    draft.placeName = name
                    draft.latitude = coord.latitude
                    draft.longitude = coord.longitude
                    draft.address = address
                }
            }
        }
    }
}
