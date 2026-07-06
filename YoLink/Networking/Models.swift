import Foundation


struct APIResponse<T: Decodable>: Decodable {
    let data: T
    let error: String?
}


enum EventMode: String, Codable {
    case online, offline, hybrid
}

enum EventStatus: String, Codable {
    case draft, published, cancelled
}

enum AttendeeRole: String, Codable {
    case host, attendee
}

enum AttendeeStatus: String, Codable {
    case pending, confirmed, cancelled
}

enum NetworkingActionType: String, Codable {
    case like, skip
}



struct AuthData: Decodable {
    struct UserInfo: Decodable {
        let id: String
        let email: String
    }
    struct ProfileInfo: Decodable {
        let id: String
        let displayName: String
    }
    let user: UserInfo
    let profile: ProfileInfo
}

/// Full wrapped response: { "data": { "user": {...}, "profile": {...} }, "error": null }
typealias AuthResponse = APIResponse<AuthData>

/// The "data" content returned by /auth/me
struct MeData: Decodable {
    let profile: MyProfile
}

/// Full wrapped response for /auth/me
typealias MeResponse = APIResponse<MeData>

/// The profile fields returned by GET /api/auth/me
/// Only these specific fields — backend selects exactly this subset
struct MyProfile: Decodable {
    let id: String
    let displayName: String
    let headline: String?
    let bio: String?
    let avatarUrl: String?
    let company: String?
    let title: String?
    let location: String?
}

// ============================================================
// MARK: - Event Models
// ============================================================

/// Host info embedded in event list and detail responses
struct EventHostInfo: Decodable {
    let id: String
    let displayName: String
    let avatarUrl: String?
}

/// Single event in the list view
/// Lighter shape — no description, capacity, or status
struct EventListItem: Decodable, Identifiable {
    let id: String
    let title: String
    let startTime: String
    let endTime: String?
    let locationText: String?
    let eventMode: EventMode
    let coverImageUrl: String?
    let hostProfile: EventHostInfo

    var startDate: Date? { ISO8601DateFormatter().date(from: startTime) }
    var endDate: Date? {
        guard let end = endTime else { return nil }
        return ISO8601DateFormatter().date(from: end)
    }
}

/// The "data" content returned by GET /api/events
struct EventsData: Decodable {
    let events: [EventListItem]
}

/// Full wrapped response for events list
typealias EventsResponse = APIResponse<EventsData>

/// Full event detail returned by GET /api/events/:id
struct EventDetail: Decodable, Identifiable {
    struct HostProfile: Decodable {
        let id: String
        let displayName: String
        let avatarUrl: String?
        let headline: String?
    }
    struct AttendeeCount: Decodable {
        let attendees: Int
    }

    let id: String
    let title: String
    let description: String?
    let startTime: String
    let endTime: String?
    let locationText: String?
    let eventMode: EventMode
    let capacity: Int?
    let coverImageUrl: String?
    let status: EventStatus
    let hostProfile: HostProfile
    let count: AttendeeCount

    enum CodingKeys: String, CodingKey {
        case id, title, description, startTime, endTime
        case locationText, eventMode, capacity, coverImageUrl
        case status, hostProfile
        case count = "_count"   // ← Prisma returns this as "_count"
    }

    var isFull: Bool {
        guard let cap = capacity else { return false }
        return count.attendees >= cap
    }
    var startDate: Date? { ISO8601DateFormatter().date(from: startTime) }
    var endDate: Date? {
        guard let end = endTime else { return nil }
        return ISO8601DateFormatter().date(from: end)
    }
}

/// The "data" content returned by GET /api/events/:id
struct EventDetailData: Decodable {
    let event: EventDetail
}

/// Full wrapped response for event detail
typealias EventDetailResponse = APIResponse<EventDetailData>

/// The "data" content returned by POST /api/events
/// Backend only returns the new event's ID
struct CreateEventData: Decodable {
    struct CreatedEvent: Decodable { let id: String }
    let event: CreatedEvent
}

/// Full wrapped response for create event
typealias CreateEventResponse = APIResponse<CreateEventData>

// ============================================================
// MARK: - Attendee Models
// ============================================================

struct AttendeeProfile: Decodable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let headline: String?
}

struct AttendeeRecord: Decodable, Identifiable {
    let id: String
    let role: AttendeeRole
    let createdAt: String
    let profile: AttendeeProfile
}

/// The "data" content returned by GET /api/events/:id/attendees
struct AttendeesData: Decodable {
    let attendees: [AttendeeRecord]
}

/// Full wrapped response for attendees list
typealias AttendeesResponse = APIResponse<AttendeesData>

// ============================================================
// MARK: - Ok Response
// Logout and attend return { "data": { "ok": true }, "error": null }
// ============================================================

struct OkData: Decodable {
    let ok: Bool
}

typealias OkResponse = APIResponse<OkData>

// ============================================================
// MARK: - Error Response
// When something goes wrong the shape is:
// { "data": null, "error": { "code": "...", "message": "..." } }
// The parseError function in APIClient handles this.
// ============================================================

struct APIErrorBody: Decodable {
    let code: String
    let message: String
}

// ============================================================
// MARK: - Request Body Structs
// These are what your app SENDS to the backend
// ============================================================

/// POST /api/auth/signup
struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let displayName: String
}

/// POST /api/auth/login
struct LoginRequest: Encodable {
    let email: String
    let password: String
}

/// POST /api/events
struct CreateEventRequest: Encodable {
    let title: String
    let description: String?
    let startTime: String
    let endTime: String?
    let locationText: String?
    let eventMode: EventMode
    let capacity: Int?
    let coverImageUrl: String?
}

// ============================================================
// MARK: - Filter Enum (for GET /api/events?filter=)
// ============================================================

enum EventFilter: String {
    case all
    case joined
    case recommended
}
