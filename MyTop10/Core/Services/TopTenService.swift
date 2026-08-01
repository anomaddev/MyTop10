import Foundation
import Supabase

@MainActor
final class TopTenService {
    private var db: SupabaseClient { SupabaseManager.client }

    func fetchMyLists(ownerId: String) async throws -> [TopTen] {
        try await db
            .from("top_tens")
            .select()
            .eq("owner_id", value: ownerId)
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

    func fetchItems(for topTenId: UUID) async throws -> [TopTenItem] {
        try await db
            .from("top_ten_items")
            .select()
            .eq("top_ten_id", value: topTenId.uuidString)
            .order("rank", ascending: true)
            .execute()
            .value
    }

    func createList(
        ownerId: String,
        title: String,
        categoryId: UUID?,
        visibility: ListVisibility,
        items: [(title: String, note: String?, placeName: String?, lat: Double?, lng: Double?, address: String?)]
    ) async throws -> TopTen {
        var payload: [String: AnyJSON] = [
            "owner_id": .string(ownerId),
            "title": .string(title),
            "visibility": .string(visibility.rawValue),
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

        if !items.isEmpty {
            let rows: [[String: AnyJSON]] = items.enumerated().map { index, item in
                var row: [String: AnyJSON] = [
                    "top_ten_id": .string(list.id.uuidString),
                    "rank": .integer(index + 1),
                    "title": .string(item.title)
                ]
                if let note = item.note { row["note"] = .string(note) }
                if let placeName = item.placeName { row["place_name"] = .string(placeName) }
                if let lat = item.lat { row["lat"] = .double(lat) }
                if let lng = item.lng { row["lng"] = .double(lng) }
                if let address = item.address { row["address"] = .string(address) }
                return row
            }
            try await db.from("top_ten_items").insert(rows).execute()
        }
        return list
    }

    func updateListMeta(_ list: TopTen) async throws {
        let payload: [String: AnyJSON] = [
            "title": .string(list.title),
            "visibility": .string(list.visibility.rawValue),
            "category_id": list.categoryId.map { .string($0.uuidString) } ?? .null,
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        try await db.from("top_tens").update(payload).eq("id", value: list.id.uuidString).execute()
    }

    func replaceItems(topTenId: UUID, items: [TopTenItem]) async throws {
        try await db.from("top_ten_items").delete().eq("top_ten_id", value: topTenId.uuidString).execute()
        guard !items.isEmpty else { return }
        let rows: [[String: AnyJSON]] = items.enumerated().map { index, item in
            var row: [String: AnyJSON] = [
                "top_ten_id": .string(topTenId.uuidString),
                "rank": .integer(index + 1),
                "title": .string(item.title)
            ]
            if let note = item.note { row["note"] = .string(note) }
            if let placeName = item.placeName { row["place_name"] = .string(placeName) }
            if let lat = item.latitude { row["lat"] = .double(lat) }
            if let lng = item.longitude { row["lng"] = .double(lng) }
            if let address = item.address { row["address"] = .string(address) }
            return row
        }
        try await db.from("top_ten_items").insert(rows).execute()
    }

    func deleteList(id: UUID) async throws {
        try await db.from("top_tens").delete().eq("id", value: id.uuidString).execute()
    }

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
}
