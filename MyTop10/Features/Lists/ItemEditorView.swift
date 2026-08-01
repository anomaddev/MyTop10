import SwiftUI

struct ItemEditorView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let listId: UUID
    let rank: Int
    let existing: TopTenItem?
    var onSaved: (TopTenItem) -> Void

    @State private var draft: ItemDraft
    @State private var showMapPicker = false
    @State private var isSaving = false
    @State private var error: String?

    init(listId: UUID, rank: Int, existing: TopTenItem?, onSaved: @escaping (TopTenItem) -> Void) {
        self.listId = listId
        self.rank = rank
        self.existing = existing
        self.onSaved = onSaved
        _draft = State(initialValue: existing.map(ItemDraft.init) ?? ItemDraft())
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

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
                                .frame(minHeight: 110)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        TagEditor(tags: $draft.tags)

                        VStack(alignment: .leading, spacing: 8) {
                            FieldLabel(text: "Your rating")
                            StarRatingControl(rating: $draft.rating)
                        }

                        PhotoStripEditor(remoteUrls: $draft.photoUrls, localPhotos: $draft.localPhotos)

                        Toggle(isOn: $draft.isFavorite) {
                            Label("Favorite", systemImage: "heart.fill")
                                .font(.custom("AvenirNext-DemiBold", size: 16))
                                .foregroundStyle(Theme.ink)
                        }
                        .tint(Theme.coral)

                        DatePicker(
                            "Visited on",
                            selection: Binding(
                                get: { draft.visitedOn ?? Date() },
                                set: { draft.visitedOn = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .opacity(draft.visitedOn == nil ? 0.55 : 1)

                        Toggle("Mark as visited", isOn: Binding(
                            get: { draft.visitedOn != nil },
                            set: { draft.visitedOn = $0 ? (draft.visitedOn ?? Date()) : nil }
                        ))
                        .tint(Theme.lagoon)

                        HStack(spacing: 10) {
                            Button {
                                showMapPicker = true
                            } label: {
                                Label(
                                    draft.latitude == nil
                                        ? "Pin a place"
                                        : (draft.placeName.isEmpty ? "Location pinned" : draft.placeName),
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

                            if draft.latitude != nil {
                                Button("Clear") {
                                    draft.latitude = nil
                                    draft.longitude = nil
                                    draft.placeName = ""
                                    draft.address = ""
                                }
                                .font(.custom("AvenirNext-Medium", size: 13))
                                .foregroundStyle(Theme.coral)
                            }
                        }

                        if let address = Optional(draft.address), !address.isEmpty {
                            Text(address)
                                .font(.custom("AvenirNext-Regular", size: 13))
                                .foregroundStyle(Theme.mutedText)
                        }

                        if let error {
                            ErrorBanner(message: error)
                        }

                        Button(isSaving ? "Saving…" : "Save item") {
                            Task { await save() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSave)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existing == nil ? "Add item" : "Edit item")
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

    private func save() async {
        guard let uid = session.auth.uid else { return }
        isSaving = true
        defer { isSaving = false }
        error = nil
        do {
            let saved = try await session.lists.saveItemDraft(
                topTenId: listId,
                ownerId: uid,
                draft: draft,
                rank: rank,
                isNew: existing == nil
            )
            onSaved(saved)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
