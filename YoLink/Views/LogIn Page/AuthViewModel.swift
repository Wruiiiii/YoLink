import SwiftUI
import AuthenticationServices

@Observable
final class AuthViewModel {

    // MARK: - State

    var email:    String = ""
    var password: String = ""

    /// Legacy phone field (kept for existing code compatibility)
    var phoneNumber: String = ""

    /// When true, ContentView switches to MainTabView
    var showMainTabView: Bool = false

    var isLoggedIn:     Bool = false
    var showErrorAlert: Bool = false
    var errorMessage:   String = ""
    var isLoading:      Bool = false

    // MARK: - Email / Password Login
    // Demo credentials: yolink@genius.com / 123

    func performEmailLogin() {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty
        else {
            errorMessage   = "Please enter your email and password."
            showErrorAlert = true
            return
        }

        if email.lowercased().trimmingCharacters(in: .whitespaces) == "yolink@genius.com"
            && password == "123" {
            showMainTabView = true
        } else {
            errorMessage   = "Invalid email or password."
            showErrorAlert = true
        }
    }

    // MARK: - Mock Phone Login (preserved)

    func performPhoneLogin() {
        let normalized = phoneNumber
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        guard normalized == "1234567890" else {
            errorMessage   = "Invalid phone number. Use 1234567890 for mock success."
            showErrorAlert = true
            return
        }
        showMainTabView = true
    }

    // MARK: - Mock Google Login (preserved)

    func performGoogleLogin() {
        print("Google Auth Triggered")
        isLoggedIn      = true
        showMainTabView = true
    }

    // MARK: - Apple Sign-In (preserved)

    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                print("Apple Sign-In: \(credential.user)")
                isLoggedIn      = true
                showMainTabView = true
            }
        case .failure(let error):
            print("Apple Sign-In failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Footer Actions (preserved)

    func onTermsOfServiceTapped() { print("Terms tapped") }
    func onSignUpTapped()         { print("Sign-up tapped") }
}
