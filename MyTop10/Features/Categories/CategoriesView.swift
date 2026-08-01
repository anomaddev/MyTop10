import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject private var session: AppSession
    @State private var categories: [Category] = []
    @State private var selected: Category?
    @State private var lists: [TopTen] = []
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                List {
                    Section("Browse") {
                        ForEach(categories) { category in
                            Button {
                                selected = category
                                Task { await loadLists(for: category) }
                            } label: {
                                HStack {
                                    Image(systemName: category.icon ?? "square.grid.2x2")
                                        .foregroundStyle(Theme.lagoon)
                                    Text(category.name)
                                        .font(.custom("AvenirNext-DemiBold", size: 16))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    if category.isSystem {
                                        Text("Curated")
                                            .font(.custom("AvenirNext-Medium", size: 11))
                                            .foregroundStyle(Theme.mutedText)
                                    }
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.65))
                        }
                    }

                    if let selected {
                        Section(selected.name) {
                            if lists.isEmpty {
                                Text("No public lists in this category yet.")
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
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                TopTenDetailView(listId: id)
            }
            .alert("Custom category", isPresented: $showCreate) {
                TextField("Name", text: $newName)
                Button("Create") {
                    Task { await createCategory() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task { await loadCategories() }
        }
    }

    private func loadCategories() async {
        categories = (try? await session.lists.fetchCategories()) ?? []
    }

    private func loadLists(for category: Category) async {
        lists = (try? await session.lists.fetchByCategory(category.id)) ?? []
    }

    private func createCategory() async {
        guard let uid = session.auth.uid, !newName.isEmpty else { return }
        _ = try? await session.lists.createCustomCategory(name: newName, userId: uid)
        newName = ""
        await loadCategories()
    }
}
