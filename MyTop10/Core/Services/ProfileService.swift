import Foundation
import Supabase
import UIKit

@MainActor
final class ProfileService {
    private var db: SupabaseClient { SupabaseManager.client }

    func fetchProfile(id: String) async throws -> Profile? {
        let rows: [Profile] = try await db
            .from("profiles")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func isUsernameAvailable(_ username: String, excluding userId: String?) async throws -> Bool {
        struct Row: Decodable { let id: String }
        var query = db.from("profiles").select("id").eq("username", value: username.lowercased())
        if let userId {
            query = query.neq("id", value: userId)
        }
        let rows: [Row] = try await query.limit(1).execute().value
        return rows.isEmpty
    }

    func upsertProfile(
        id: String,
        username: String,
        fullName: String,
        avatarUrl: String?
    ) async throws -> Profile {
        let payload: [String: AnyJSON] = [
            "id": .string(id),
            "username": .string(username.lowercased()),
            "full_name": .string(fullName),
            "avatar_url": avatarUrl.map { .string($0) } ?? .null,
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        let profile: Profile = try await db
            .from("profiles")
            .upsert(payload)
            .select()
            .single()
            .execute()
            .value
        return profile
    }

    func updateProfile(_ profile: Profile) async throws -> Profile {
        try await upsertProfile(
            id: profile.id,
            username: profile.username,
            fullName: profile.fullName,
            avatarUrl: profile.avatarUrl
        )
    }

    func uploadAvatar(userId: String, image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw AuthError.unknown("Could not process image")
        }
        let path = "\(userId)/avatar.jpg"
        try await db.storage
            .from("avatars")
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        let publicURL = try db.storage.from("avatars").getPublicURL(path: path)
        return publicURL.absoluteString
    }

    func follow(followerId: String, followingId: String) async throws {
        let payload: [String: AnyJSON] = [
            "follower_id": .string(followerId),
            "following_id": .string(followingId)
        ]
        try await db.from("follows").upsert(payload).execute()
    }

    func unfollow(followerId: String, followingId: String) async throws {
        try await db
            .from("follows")
            .delete()
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .execute()
    }

    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        let rows: [Follow] = try await db
            .from("follows")
            .select()
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    func followerCount(for userId: String) async throws -> Int {
        let rows: [Follow] = try await db
            .from("follows")
            .select()
            .eq("following_id", value: userId)
            .execute()
            .value
        return rows.count
    }

    func followingCount(for userId: String) async throws -> Int {
        let rows: [Follow] = try await db
            .from("follows")
            .select()
            .eq("follower_id", value: userId)
            .execute()
            .value
        return rows.count
    }
}
