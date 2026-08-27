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

    var systemImage: String {
        switch self {
        case .private: return "lock.fill"
        case .followers: return "person.2.fill"
        case .public: return "globe"
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
    var sortOrder: Int
    var upvotes: Int
    var downvotes: Int
    var createdAt: Date?
    var updatedAt: Date?

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
        case sortOrder = "sort_order"
        case upvotes
        case downvotes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        ownerId: String,
        title: String,
        categoryId: UUID? = nil,
        visibility: ListVisibility = .public,
        coverUrl: String? = nil,
        sortOrder: Int = 0,
        upvotes: Int = 0,
        downvotes: Int = 0,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.categoryId = categoryId
        self.visibility = visibility
        self.coverUrl = coverUrl
        self.sortOrder = sortOrder
        self.upvotes = upvotes
        self.downvotes = downvotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ownerId = try c.decode(String.self, forKey: .ownerId)
        title = try c.decode(String.self, forKey: .title)
        categoryId = try c.decodeIfPresent(UUID.self, forKey: .categoryId)
        visibility = try c.decode(ListVisibility.self, forKey: .visibility)
        coverUrl = try c.decodeIfPresent(String.self, forKey: .coverUrl)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        upvotes = try c.decodeIfPresent(Int.self, forKey: .upvotes) ?? 0
        downvotes = try c.decodeIfPresent(Int.self, forKey: .downvotes) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var score: Int { upvotes - downvotes }
}

struct TopTenItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var topTenId: UUID
    var rank: Int
    var title: String
    var note: String?
    var tags: [String]
    var photoUrls: [String]
    var rating: Int?
    var isFavorite: Bool
    var visitedOn: Date?
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, rank, title, note, address, tags, rating
        case topTenId = "top_ten_id"
        case photoUrls = "photo_urls"
        case isFavorite = "is_favorite"
        case visitedOn = "visited_on"
        case placeName = "place_name"
        case latitude = "lat"
        case longitude = "lng"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        topTenId: UUID,
        rank: Int,
        title: String,
        note: String? = nil,
        tags: [String] = [],
        photoUrls: [String] = [],
        rating: Int? = nil,
        isFavorite: Bool = false,
        visitedOn: Date? = nil,
        placeName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil
    ) {
        self.id = id
        self.topTenId = topTenId
        self.rank = rank
        self.title = title
        self.note = note
        self.tags = tags
        self.photoUrls = photoUrls
        self.rating = rating
        self.isFavorite = isFavorite
        self.visitedOn = visitedOn
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        topTenId = try c.decode(UUID.self, forKey: .topTenId)
        rank = try c.decode(Int.self, forKey: .rank)
        title = try c.decode(String.self, forKey: .title)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        photoUrls = try c.decodeIfPresent([String].self, forKey: .photoUrls) ?? []
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        // Postgres `date` often arrives as "yyyy-MM-dd"
        if let raw = try c.decodeIfPresent(String.self, forKey: .visitedOn) {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"
            visitedOn = df.date(from: raw)
        } else {
            visitedOn = try c.decodeIfPresent(Date.self, forKey: .visitedOn)
        }
        placeName = try c.decodeIfPresent(String.self, forKey: .placeName)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasLocation: Bool { coordinate != nil }
    var hasPhotos: Bool { !photoUrls.isEmpty }
    var hasTags: Bool { !tags.isEmpty }
    var hasNote: Bool { !(note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
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

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case phone
    case otp
    case profile
    case permissions
    case complete
}

/// Draft used while creating / editing an item before persistence.
struct ItemDraft: Identifiable, Equatable {
    var id: UUID
    var title: String
    var note: String
    var tags: [String]
    var photoUrls: [String]
    var localPhotos: [Data]
    var rating: Int?
    var isFavorite: Bool
    var visitedOn: Date?
    var placeName: String
    var latitude: Double?
    var longitude: Double?
    var address: String

    init(
        id: UUID = UUID(),
        title: String = "",
        note: String = "",
        tags: [String] = [],
        photoUrls: [String] = [],
        localPhotos: [Data] = [],
        rating: Int? = nil,
        isFavorite: Bool = false,
        visitedOn: Date? = nil,
        placeName: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String = ""
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.tags = tags
        self.photoUrls = photoUrls
        self.localPhotos = localPhotos
        self.rating = rating
        self.isFavorite = isFavorite
        self.visitedOn = visitedOn
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }

    init(item: TopTenItem) {
        self.init(
            id: item.id,
            title: item.title,
            note: item.note ?? "",
            tags: item.tags,
            photoUrls: item.photoUrls,
            rating: item.rating,
            isFavorite: item.isFavorite,
            visitedOn: item.visitedOn,
            placeName: item.placeName ?? "",
            latitude: item.latitude,
            longitude: item.longitude,
            address: item.address ?? ""
        )
    }
}
