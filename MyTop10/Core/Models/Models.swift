import Foundation
import CoreLocation

struct Profile: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var username: String
    var fullName: String
    var avatarUrl: String?
    var bio: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case bio
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Category: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var slug: String
    var isSystem: Bool
    var createdBy: String?
    var icon: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, icon
        case isSystem = "is_system"
        case createdBy = "created_by"
    }
}

enum ListVisibility: String, Codable, CaseIterable, Identifiable {
    case `private`
    case followers
    case `public`

    var id: String { rawValue }

    var label: String {
        switch self {
        case .private: return "Private"
        case .followers: return "Followers"
        case .public: return "Public"
        }
    }
}

struct TopTen: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var ownerId: String
    var title: String
    var categoryId: UUID?
    var visibility: ListVisibility
    var coverUrl: String?
    var upvotes: Int
    var downvotes: Int
    var createdAt: Date?
    var updatedAt: Date?

    /// Joined / client-side helpers
    var category: Category?
    var items: [TopTenItem]?
    var owner: Profile?
    var userVote: Int?
    var isBookmarked: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, visibility
        case ownerId = "owner_id"
        case categoryId = "category_id"
        case coverUrl = "cover_url"
        case upvotes
        case downvotes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var score: Int { upvotes - downvotes }
}

struct TopTenItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var topTenId: UUID
    var rank: Int
    var title: String
    var note: String?
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    var address: String?

    enum CodingKeys: String, CodingKey {
        case id, rank, title, note, address
        case topTenId = "top_ten_id"
        case placeName = "place_name"
        case latitude = "lat"
        case longitude = "lng"
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasLocation: Bool { coordinate != nil }
}

struct Vote: Identifiable, Codable, Equatable {
    let id: UUID?
    var userId: String
    var topTenId: UUID
    var value: Int

    enum CodingKeys: String, CodingKey {
        case id, value
        case userId = "user_id"
        case topTenId = "top_ten_id"
    }
}

struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID?
    var userId: String
    var topTenId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case topTenId = "top_ten_id"
    }
}

struct Follow: Identifiable, Codable, Equatable {
    let id: UUID?
    var followerId: String
    var followingId: String

    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
    }
}

struct PasswordRequirement: Identifiable {
    let id = UUID()
    let label: String
    let isMet: Bool
}

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case phone
    case otp
    case profile
    case permissions
    case complete
}
