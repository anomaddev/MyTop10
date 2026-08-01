import SwiftUI

struct ListSettingsSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State var list: TopTen
    @State private var categories: [Category] = []
    @State private var isSaving = false
    @State private var error: String?
    var onSaved: (TopTen) -> Void
    var onDeleted: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("List") {
                    TextField("Title", text: $list.title)
                    Picker("Visibility", selection: $list.visibility) {
                        ForEach(ListVisibility.allCases) { visibility in
                            Label(visibility.label, systemImage: visibility.systemImage)
                                .tag(visibility)
                        }
                    }
                    Picker("Category", selection: $list.categoryId) {
                        Text("None").tag(UUID?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }

                if let error {
                    Section { ErrorBanner(message: error) }
                }

                Section {
                    Button(isSaving ? "Saving…" : "Save changes") {
                        Task { await save() }
                    }
                    .disabled(list.title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }

                Section {
                    Button("Delete list", role: .destructive) {
                        Task { await deleteList() }
                    }
                }
            }
            .navigationTitle("List settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                categories = (try? await session.lists.fetchCategories()) ?? []
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await session.lists.updateListMeta(list)
            onSaved(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteList() async {
        do {
            try await session.lists.deleteList(id: list.id)
            onDeleted()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
