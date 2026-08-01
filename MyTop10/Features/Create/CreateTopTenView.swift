import SwiftUI
import MapKit

struct DraftItem: Identifiable {
    let id = UUID()
    var title: String = ""
    var note: String = ""
    var placeName: String = ""
    var latitude: Double?
    var longitude: Double?
    var address: String = ""
}

struct CreateTopTenView: View {
    @EnvironmentObject private var session: AppSession
    @State private var title = ""
    @State private var categories: [Category] = []
    @State private var categoryId: UUID?
    @State private var visibility: ListVisibility = .public
    @State private var items: [DraftItem] = (1...10).map { _ in DraftItem() }
    @State private var pinningIndex: Int?
    @State private var error: String?
    @State private var isSaving = false
    @State private var showSuccess = false
    private let interstitial = InterstitialAdCoordinator()

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                Form {
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
                                Text(v.label).tag(v)
                            }
                        }
                    }

                    Section("Your Top 10") {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, _ in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Rank \(index + 1)", text: $items[index].title)
                                    .font(.custom("AvenirNext-DemiBold", size: 16))
                                TextField("Note (optional)", text: $items[index].note)
                                    .font(.custom("AvenirNext-Regular", size: 14))
                                Button {
                                    pinningIndex = index
                                } label: {
                                    Label(
                                        items[index].latitude == nil ? "Pin location" : (items[index].placeName.isEmpty ? "Location pinned" : items[index].placeName),
                                        systemImage: "mappin.circle"
                                    )
                                    .font(.custom("AvenirNext-Medium", size: 13))
                                    .foregroundStyle(Theme.deepTeal)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove { source, dest in
                            items.move(fromOffsets: source, toOffset: dest)
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
            .sheet(isPresented: Binding(
                get: { pinningIndex != nil },
                set: { if !$0 { pinningIndex = nil } }
            )) {
                if let index = pinningIndex {
                    LocationPickerView { name, coord, address in
                        items[index].placeName = name
                        items[index].latitude = coord.latitude
                        items[index].longitude = coord.longitude
                        items[index].address = address
                    }
                }
            }
            .alert("Published", isPresented: $showSuccess) {
                Button("OK") {
                    interstitial.showIfReady()
                    reset()
                }
            } message: {
                Text("Your Top 10 is live.")
            }
        }
    }

    private func save() async {
        guard let uid = session.auth.uid else { return }
        isSaving = true
        defer { isSaving = false }
        error = nil
        let payload = items
            .map { item in
                (
                    title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    note: item.note.isEmpty ? nil : item.note,
                    placeName: item.placeName.isEmpty ? nil : item.placeName,
                    lat: item.latitude,
                    lng: item.longitude,
                    address: item.address.isEmpty ? nil : item.address
                )
            }
            .filter { !$0.title.isEmpty }

        do {
            _ = try await session.lists.createList(
                ownerId: uid,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryId: categoryId,
                visibility: visibility,
                items: payload
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
        items = (1...10).map { _ in DraftItem() }
    }
}
