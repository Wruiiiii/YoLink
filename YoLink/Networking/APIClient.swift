import Foundation

// ============================================================
// MARK: - API Errors
// ============================================================

enum APIError: LocalizedError {
    case invalidURL
    case notLoggedIn
    case forbidden
    case emailTaken
    case invalidCredentials
    case eventFull
    case notFound
    case badRequest(String)
    case serverError(String)
    case decodingFailed(Error)
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid server URL."
        case .notLoggedIn:          return "Please log in to continue."
        case .forbidden:            return "You don't have permission to do this."
        case .emailTaken:           return "This email is already in use."
        case .invalidCredentials:   return "Incorrect email or password."
        case .eventFull:            return "This event is full."
        case .notFound:             return "Not found."
        case .badRequest(let msg):  return msg
        case .serverError(let msg): return msg
        case .decodingFailed(let e):return "Unexpected server response: \(e.localizedDescription)"
        case .unknown(let code):    return "Something went wrong (HTTP \(code))."
        }
    }
}

// ============================================================
// MARK: - Session Store
// ============================================================

final class SessionStore {
    static let shared = SessionStore()
    private init() {}

    var userId: String? {
        get { UserDefaults.standard.string(forKey: "userId") }
        set { UserDefaults.standard.set(newValue, forKey: "userId") }
    }

    var profileId: String? {
        get { UserDefaults.standard.string(forKey: "profileId") }
        set { UserDefaults.standard.set(newValue, forKey: "profileId") }
    }

    var isLoggedIn: Bool { profileId != nil }

    func save(from data: AuthData) {
        userId    = data.user.id
        profileId = data.profile.id
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "profileId")
        HTTPCookieStorage.shared.cookies?
            .forEach { HTTPCookieStorage.shared.deleteCookie($0) }
    }
}

// ============================================================
// MARK: - SSL Bypass Delegate
// ⚠️ Development only — DELETE before App Store submission
// ============================================================

final class SSLBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod
                == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

// ============================================================
// MARK: - API Client
// ============================================================

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = "https://47.239.0.39"

    // Decoder: snake_case keys → camelCase Swift properties
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // Encoder: no key strategy — sends camelCase as-is
    // Your JS backend expects camelCase (displayName, not display_name)
    private let encoder = JSONEncoder()

    // Custom session that trusts the self-signed certificate
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(
            configuration: config,
            delegate: SSLBypassDelegate(),
            delegateQueue: nil
        )
    }()

    // ─────────────────────────────────────────────────────
    // MARK: Request Builder
    // ─────────────────────────────────────────────────────

    private func makeRequest(
        path: String,
        method: String,
        body: (some Encodable)? = nil as String?
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpShouldHandleCookies = true
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        return req
    }

    // ─────────────────────────────────────────────────────
    // MARK: Response Handler
    // All responses are wrapped: { "data": {...}, "error": null }
    // ─────────────────────────────────────────────────────

    private func parseError(from data: Data, status: Int) -> APIError {
        // Try to read the error body
        struct ErrorWrapper: Decodable {
            struct ErrorBody: Decodable { let code: String; let message: String }
            let error: ErrorBody?
        }
        let wrapper = try? decoder.decode(ErrorWrapper.self, from: data)
        switch wrapper?.error?.code {
        case "EMAIL_TAKEN":          return .emailTaken
        case "INVALID_CREDENTIALS":  return .invalidCredentials
        case "UNAUTHORIZED":         return .notLoggedIn
        case "FORBIDDEN":            return .forbidden
        case "NOT_FOUND":            return .notFound
        case "FULL":                 return .eventFull
        case "BAD_REQUEST":          return .badRequest(wrapper?.error?.message ?? "Invalid input.")
        default:                     return .unknown(status)
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw parseError(from: data, status: http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    // ============================================================
    // MARK: - Auth Endpoints
    // ============================================================

    /// POST /api/auth/signup
    func signUp(email: String, password: String, displayName: String) async throws -> AuthData {
        let body = SignUpRequest(email: email, password: password, displayName: displayName)
        let req  = try makeRequest(path: "/api/auth/signup", method: "POST", body: body)
        let response: AuthResponse = try await perform(req)
        SessionStore.shared.save(from: response.data)
        return response.data
    }

    /// POST /api/auth/login
    func login(email: String, password: String) async throws -> AuthData {
        let body = LoginRequest(email: email, password: password)
        let req  = try makeRequest(path: "/api/auth/login", method: "POST", body: body)
        let response: AuthResponse = try await perform(req)
        SessionStore.shared.save(from: response.data)
        return response.data
    }

    /// POST /api/auth/logout
    func logout() async throws {
        let req = try makeRequest(path: "/api/auth/logout", method: "POST")
        let _: OkResponse = try await perform(req)
        SessionStore.shared.clear()
    }

    /// GET /api/auth/me
    func getMe() async throws -> MyProfile {
        let req = try makeRequest(path: "/api/auth/me", method: "GET")
        let response: MeResponse = try await perform(req)
        return response.data.profile
    }

    // ============================================================
    // MARK: - Event Endpoints
    // ============================================================

    /// GET /api/events?filter=all|joined|recommended
    func getEvents(filter: EventFilter = .all) async throws -> [EventListItem] {
        let req = try makeRequest(
            path: "/api/events?filter=\(filter.rawValue)",
            method: "GET"
        )
        let response: EventsResponse = try await perform(req)
        return response.data.events
    }

    /// GET /api/events/:id
    func getEvent(id: String) async throws -> EventDetail {
        let req = try makeRequest(path: "/api/events/\(id)", method: "GET")
        let response: EventDetailResponse = try await perform(req)
        return response.data.event
    }

    /// POST /api/events — returns only the new event's ID
    func createEvent(_ event: CreateEventRequest) async throws -> String {
        let req = try makeRequest(path: "/api/events", method: "POST", body: event)
        let response: CreateEventResponse = try await perform(req)
        return response.data.event.id
    }

    /// POST /api/events/:id/attend
    func attendEvent(id: String) async throws {
        let req = try makeRequest(path: "/api/events/\(id)/attend", method: "POST")
        let _: OkResponse = try await perform(req)
    }

    /// GET /api/events/:id/attendees — host only
    func getAttendees(eventId: String) async throws -> [AttendeeRecord] {
        let req = try makeRequest(
            path: "/api/events/\(eventId)/attendees",
            method: "GET"
        )
        let response: AttendeesResponse = try await perform(req)
        return response.data.attendees
    }
}
