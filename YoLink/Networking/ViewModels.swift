import SwiftUI
import Combine

@MainActor
final class AppSessionViewModel: ObservableObject {
    @Published var isLoggedIn  = false
    @Published var myProfile:  MyProfile?
    @Published var isRestoring = true

    /// Called on app launch — checks if the saved session cookie is still valid.
    func restoreSession() async {
        isRestoring = true
        do {
            let profile = try await APIClient.shared.getMe()
            myProfile   = profile
            isLoggedIn  = true
        } catch {
            isLoggedIn  = false
        }
        isRestoring = false
    }

    /// Logs out and resets all state.
    func logout() async {
        try? await APIClient.shared.logout()
        isLoggedIn = false
        myProfile  = nil
    }
}


@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var isLoading    = false
    @Published var errorMessage: String?
    @Published var isSuccess    = false

    func signUp(email: String, password: String, displayName: String) async {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name."; return
        }
        guard displayName.count <= 80 else {
            errorMessage = "Name must be 80 characters or fewer."; return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."; return
        }
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email address."; return
        }

        isLoading    = true
        errorMessage = nil

        do {
            _ = try await APIClient.shared.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
            isSuccess = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Network error. Please check your connection."
        }

        isLoading = false
    }
}

// ============================================================
// MARK: - Login ViewModel
//
// Usage in a LoginView backed by real email/password:
//   @StateObject private var vm = LoginViewModel()
//   await vm.login(email:password:)
// ============================================================

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading    = false
    @Published var errorMessage: String?
    @Published var isSuccess    = false

    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."; return
        }

        isLoading    = true
        errorMessage = nil

        do {
            _ = try await APIClient.shared.login(email: email, password: password)
            isSuccess = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Network error. Please check your connection."
        }

        isLoading = false
    }
}



@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events:         [EventListItem] = []
    @Published var isLoading       = false
    @Published var errorMessage:   String?

    func load(filter: EventFilter = .all) async {
        isLoading    = true
        errorMessage = nil
        do {
            events = try await APIClient.shared.getEvents(filter: filter)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Network error."
        }
        isLoading = false
    }
}

// ============================================================
// MARK: - Event Detail ViewModel
// ============================================================

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var event:        EventDetail?
    @Published var isLoading     = false
    @Published var isJoining     = false
    @Published var joinSuccess   = false
    @Published var errorMessage: String?

    func load(eventId: String) async {
        isLoading    = true
        errorMessage = nil
        do {
            event = try await APIClient.shared.getEvent(id: eventId)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Could not load event."
        }
        isLoading = false
    }

    func join(eventId: String) async {
        isJoining    = true
        errorMessage = nil
        do {
            try await APIClient.shared.attendEvent(id: eventId)
            joinSuccess = true
            await load(eventId: eventId)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Network error."
        }
        isJoining = false
    }
}

// ============================================================
// MARK: - Create Event ViewModel
// ============================================================

@MainActor
final class CreateEventViewModel: ObservableObject {
    @Published var isLoading:     Bool = false
    @Published var errorMessage:  String?
    @Published var createdEventId: String?

    func create(
        title:         String,
        description:   String?,
        startTime:     Date,
        endTime:       Date?,
        locationText:  String?,
        mode:          EventMode,
        capacity:      Int?,
        coverImageUrl: String?
    ) async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a title."; return
        }
        guard title.count <= 140 else {
            errorMessage = "Title must be 140 characters or fewer."; return
        }
        guard startTime > Date() else {
            errorMessage = "Start time must be in the future."; return
        }
        if let end = endTime, end <= startTime {
            errorMessage = "End time must be after start time."; return
        }

        isLoading    = true
        errorMessage = nil

        let fmt = ISO8601DateFormatter()
        let body = CreateEventRequest(
            title:         title,
            description:   description?.isEmpty == true ? nil : description,
            startTime:     fmt.string(from: startTime),
            endTime:       endTime.map { fmt.string(from: $0) },
            locationText:  locationText?.isEmpty == true ? nil : locationText,
            eventMode:     mode,
            capacity:      capacity,
            coverImageUrl: coverImageUrl?.isEmpty == true ? nil : coverImageUrl
        )

        do {
            createdEventId = try await APIClient.shared.createEvent(body)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Network error."
        }

        isLoading = false
    }
}

// ============================================================
// MARK: - Attendees ViewModel (host only)
// ============================================================

@MainActor
final class AttendeesViewModel: ObservableObject {
    @Published var attendees:    [AttendeeRecord] = []
    @Published var isLoading     = false
    @Published var errorMessage: String?

    func load(eventId: String) async {
        isLoading    = true
        errorMessage = nil
        do {
            attendees = try await APIClient.shared.getAttendees(eventId: eventId)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Network error."
        }
        isLoading = false
    }
}
