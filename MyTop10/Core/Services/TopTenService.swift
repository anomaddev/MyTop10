import Foundation
import Supabase
import UIKit

struct ItemWritePayload {
    var title: String
    var note: String?
    var tags: [String]
    var photoUrls: [String]
    var rating: Int?
    var isFavorite: Bool
    var visitedOn: Date?
    var placeName: String?
    var lat: Double?
    var lng: Double?
    var address: String?

    init(draft: ItemDraft, photoUrls: [String]? = nil) {
        title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        note = trimmedNote.isEmpty ? nil : trimmedNote
        tags = draft.tags
        self.photoUrls = photoUrls ?? draft.photoUrls
        rating = draft.rating
        isFavorite = draft.isFavorite
        visitedOn = draft.visitedOn
        placeName = draft.placeName.isEmpty ? nil : draft.placeName
        lat = draft.latitude
        lng = draft.longitude
        address = draft.address.isEmpty ? nil : draft.address
    }
}

@MainActor
final class TopTenService {
    private var db: SupabaseClient { SupabaseManager.client }

    private var isoFormatter: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    private var dateOnlyFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    // MARK: - Lists

    func fetchMyLists(ownerId: String) async throws -> [TopTen] {
        try await db
            .from("top_tens")
            .select()
            .eq("owner_id", value: ownerId)
            .order("sort_order", ascending: true)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func fetchDiscover(limit: Int = 40) async throws -> [TopTen] {
        try await db
            .from("top_tens")
            .select()
            .eq("visibility", value: ListVisibility.public.rawValue)
            .order("upvotes", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchByCategory(_ categoryId: UUID) async throws -> [TopTen] {
        try await db
            .from("top_tens")
            .select()
            .eq("category_id", value: categoryId.uuidString)
            .eq("visibility", value: ListVisibility.public.rawValue)
            .order("upvotes", ascending: false)
            .execute()
            .value
    }

    func fetchList(id: UUID) async throws -> TopTen {
        try await db
            .from("top_tens")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func createList(
        ownerId: String,
        title: String,
        categoryId: UUID?,
        visibility: ListVisibility,
        drafts: [ItemDraft]
    ) async throws -> TopTen {
        let existing = try await fetchMyLists(ownerId: ownerId)
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1

        var payload: [String: AnyJSON] = [
            "owner_id": .string(ownerId),
            "title": .string(title),
            "visibility": .string(visibility.rawValue),
            "sort_order": .integer(nextOrder),
            "upvotes": .integer(0),
            "downvotes": .integer(0)
        ]
        if let categoryId {
            payload["category_id"] = .string(categoryId.uuidString)
        }

        let list: TopTen = try await db
            .from("top_tens")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        let filled = drafts.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for (index, draft) in filled.prefix(10).enumerated() {
            var urls = draft.photoUrls
            for data in draft.localPhotos {
                if let uploaded = try? await uploadItemPhoto(
                    userId: ownerId,
                    listId: list.id,
                    itemId: draft.id,
                    imageData: data
                ) {
                    urls.append(uploaded)
                }
            }
            _ = try await insertItem(
                topTenId: list.id,
                rank: index + 1,
                itemId: draft.id,
                payload: ItemWritePayload(draft: draft, photoUrls: urls)
            )
        }
        return list
    }

    func updateListMeta(_ list: TopTen) async throws -> TopTen {
        let payload: [String: AnyJSON] = [
            "title": .string(list.title),
            "visibility": .string(list.visibility.rawValue),
            "category_id": list.categoryId.map { .string($0.uuidString) } ?? .null,
            "cover_url": list.coverUrl.map { .string($0) } ?? .null,
            "updated_at": .string(isoFormatter.string(from: Date()))
        ]
        return try await db
            .from("top_tens")
            .update(payload)
            .eq("id", value: list.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func reorderLists(_ lists: [TopTen]) async throws {
        for (index, list) in lists.enumerated() {
            let payload: [String: AnyJSON] = ["sort_order": .integer(index)]
            try await db
                .from("top_tens")
                .update(payload)
                .eq("id", value: list.id.uuidString)
                .execute()
        }
    }

    func deleteList(id: UUID) async throws {
        try await db.from("top_tens").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - Items

    func fetchItems(for topTenId: UUID) async throws -> [TopTenItem] {
        try await db
            .from("top_ten_items")
            .select()
            .eq("top_ten_id", value: topTenId.uuidString)
            .order("rank", ascending: true)
            .execute()
            .value
    }

    func insertItem(
        topTenId: UUID,
        rank: Int,
        itemId: UUID = UUID(),
        payload: ItemWritePayload
    ) async throws -> TopTenItem {
        var row = itemRow(topTenId: topTenId, rank: rank, itemId: itemId, payload: payload)
        row["id"] = .string(itemId.uuidString)
        return try await db
            .from("top_ten_items")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    func updateItem(_ item: TopTenItem) async throws -> TopTenItem {
        let payload = ItemWritePayload(
            draft: ItemDraft(item: item),
            photoUrls: item.photoUrls
        )
        var row = itemRow(topTenId: item.topTenId, rank: item.rank, itemId: item.id, payload: payload)
        row["updated_at"] = .string(isoFormatter.string(from: Date()))
        return try await db
            .from("top_ten_items")
            .update(row)
            .eq("id", value: item.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func saveItemDraft(
        topTenId: UUID,
        ownerId: String,
        draft: ItemDraft,
        rank: Int,
        isNew: Bool
    ) async throws -> TopTenItem {
        var urls = draft.photoUrls
        for data in draft.localPhotos {
            let uploaded = try await uploadItemPhoto(
                userId: ownerId,
                listId: topTenId,
                itemId: draft.id,
                imageData: data
            )
            urls.append(uploaded)
        }
        let payload = ItemWritePayload(draft: draft, photoUrls: urls)
        if isNew {
            return try await insertItem(topTenId: topTenId, rank: rank, itemId: draft.id, payload: payload)
        }
        var row = itemRow(topTenId: topTenId, rank: rank, itemId: draft.id, payload: payload)
        row["updated_at"] = .string(isoFormatter.string(from: Date()))
        return try await db
            .from("top_ten_items")
            .update(row)
            .eq("id", value: draft.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteItem(id: UUID) async throws {
        try await db.from("top_ten_items").delete().eq("id", value: id.uuidString).execute()
    }

    /// Persist a new order after drag-reorder. Uses temporary ranks to avoid unique collisions.
    func reorderItems(topTenId: UUID, items: [TopTenItem]) async throws -> [TopTenItem] {
        // Phase 1: bump ranks out of the 1...10 range (stay within DB check 1...100)
        for (index, item) in items.enumerated() {
            try await db
                .from("top_ten_items")
                .update(["rank": AnyJSON.integer(50 + index)])
                .eq("id", value: item.id.uuidString)
                .execute()
        }
        // Phase 2: write final ranks
        for (index, item) in items.enumerated() {
            try await db
                .from("top_ten_items")
                .update(["rank": AnyJSON.integer(index + 1)])
                .eq("id", value: item.id.uuidString)
                .execute()
        }
        // Touch parent list
        try await db
            .from("top_tens")
            .update(["updated_at": AnyJSON.string(isoFormatter.string(from: Date()))])
            .eq("id", value: topTenId.uuidString)
            .execute()
        return try await fetchItems(for: topTenId)
    }

    func replaceItems(topTenId: UUID, items: [TopTenItem]) async throws {
        try await db.from("top_ten_items").delete().eq("top_ten_id", value: topTenId.uuidString).execute()
        guard !items.isEmpty else { return }
        for (index, item) in items.prefix(10).enumerated() {
            let payload = ItemWritePayload(draft: ItemDraft(item: item), photoUrls: item.photoUrls)
            _ = try await insertItem(
                topTenId: topTenId,
                rank: index + 1,
                itemId: item.id,
                payload: payload
            )
        }
    }

    func uploadItemPhoto(userId: String, listId: UUID, itemId: UUID, imageData: Data) async throws -> String {
        let path = "\(userId)/\(listId.uuidString)/\(itemId.uuidString)/\(UUID().uuidString).jpg"
        try await db.storage
            .from("item-photos")
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        return try db.storage.from("item-photos").getPublicURL(path: path).absoluteString
    }

    func uploadItemPhoto(userId: String, listId: UUID, itemId: UUID, image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw AuthError.unknown("Could not process photo")
        }
        return try await uploadItemPhoto(userId: userId, listId: listId, itemId: itemId, imageData: data)
    }

    // MARK: - Categories

    func fetchCategories() async throws -> [Category] {
        try await db
            .from("categories")
            .select()
            .order("is_system", ascending: false)
            .order("name", ascending: true)
            .execute()
            .value
    }

    func createCustomCategory(name: String, userId: String) async throws -> Category {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let payload: [String: AnyJSON] = [
            "name": .string(name),
            "slug": .string(slug),
            "is_system": .bool(false),
            "created_by": .string(userId)
        ]
        return try await db
            .from("categories")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Social

    func setVote(userId: String, topTenId: UUID, value: Int) async throws {
        if value == 0 {
            try await db
                .from("votes")
                .delete()
                .eq("user_id", value: userId)
                .eq("top_ten_id", value: topTenId.uuidString)
                .execute()
            return
        }
        let payload: [String: AnyJSON] = [
            "user_id": .string(userId),
            "top_ten_id": .string(topTenId.uuidString),
            "value": .integer(value)
        ]
        try await db.from("votes").upsert(payload, onConflict: "user_id,top_ten_id").execute()
    }

    func currentVote(userId: String, topTenId: UUID) async throws -> Int {
        let rows: [Vote] = try await db
            .from("votes")
            .select()
            .eq("user_id", value: userId)
            .eq("top_ten_id", value: topTenId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.value ?? 0
    }

    func setBookmark(userId: String, topTenId: UUID, bookmarked: Bool) async throws {
        if bookmarked {
            let payload: [String: AnyJSON] = [
                "user_id": .string(userId),
                "top_ten_id": .string(topTenId.uuidString)
            ]
            try await db.from("bookmarks").upsert(payload, onConflict: "user_id,top_ten_id").execute()
        } else {
            try await db
                .from("bookmarks")
                .delete()
                .eq("user_id", value: userId)
                .eq("top_ten_id", value: topTenId.uuidString)
                .execute()
        }
    }

    func isBookmarked(userId: String, topTenId: UUID) async throws -> Bool {
        let rows: [Bookmark] = try await db
            .from("bookmarks")
            .select()
            .eq("user_id", value: userId)
            .eq("top_ten_id", value: topTenId.uuidString)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    func fetchBookmarks(userId: String) async throws -> [TopTen] {
        struct Row: Decodable {
            let topTen: TopTen
            enum CodingKeys: String, CodingKey { case topTen = "top_tens" }
        }
        let rows: [Row] = try await db
            .from("bookmarks")
            .select("top_tens(*)")
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows.map(\.topTen)
    }

    // MARK: - Helpers

    private func itemRow(
        topTenId: UUID,
        rank: Int,
        itemId: UUID,
        payload: ItemWritePayload
    ) -> [String: AnyJSON] {
        var row: [String: AnyJSON] = [
            "top_ten_id": .string(topTenId.uuidString),
            "rank": .integer(rank),
            "title": .string(payload.title),
            "tags": .array(payload.tags.map { .string($0) }),
            "photo_urls": .array(payload.photoUrls.map { .string($0) }),
            "is_favorite": .bool(payload.isFavorite)
        ]
        row["note"] = payload.note.map { .string($0) } ?? .null
        row["rating"] = payload.rating.map { .integer($0) } ?? .null
        row["visited_on"] = payload.visitedOn.map { .string(dateOnlyFormatter.string(from: $0)) } ?? .null
        row["place_name"] = payload.placeName.map { .string($0) } ?? .null
        row["lat"] = payload.lat.map { .double($0) } ?? .null
        row["lng"] = payload.lng.map { .double($0) } ?? .null
        row["address"] = payload.address.map { .string($0) } ?? .null
        _ = itemId
        return row
    }
}
