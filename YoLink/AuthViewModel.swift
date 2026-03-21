//
//  AuthViewModel.swift
//  YoLink
//
//  Manages authentication state and login logic for the app.
//  Uses @Observable for SwiftUI binding with iOS 17+.
//

import SwiftUI
import AuthenticationServices

/// View model responsible for authentication flows including:
/// - Phone number (mock OTP) login
/// - Apple Sign-In
/// - Google Sign-In (mock)
@Observable
final class AuthViewModel {
    
    // MARK: - Published State
    
    /// The phone number entered by the user in the text field.
    var phoneNumber: String = ""
    
    /// When true, navigates to MainTabView (after successful phone login).
    var showMainTabView: Bool = false
    
    /// Simulates successful login state (e.g., after Google mock auth).
    var isLoggedIn: Bool = false
    
    /// Controls display of error alerts (e.g., invalid phone number).
    var showErrorAlert: Bool = false
    
    /// Message to display in the error alert.
    var errorMessage: String = ""
    
    /// Indicates whether an async auth operation is in progress (e.g., mock OTP send).
    var isLoading: Bool = false
    
    // MARK: - Mock Phone Login
    
    /// Initiates phone login. If phone equals "1234567890", routes to MainTabView.
    /// Otherwise prints error and shows alert.
    func performPhoneLogin() {
        // Normalize phone number (strip spaces/dashes for comparison)
        let normalized = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        guard normalized == "1234567890" else {
            print("Phone login error: Invalid phone number. Expected 1234567890, got: \(normalized)")
            errorMessage = "Invalid phone number. Use 1234567890 for mock success."
            showErrorAlert = true
            return
        }
        
        showMainTabView = true
    }
    
    // MARK: - Mock Google Login
    
    /// Handles "Continue with Google" button tap.
    /// Prints a log message and routes to MainTabView.
    func performGoogleLogin() {
        print("Google Auth Triggered")
        isLoggedIn = true
        showMainTabView = true
    }
    
    // MARK: - Apple Sign-In
    
    /// Handles Apple Sign-In completion from `SignInWithAppleButton`.
    /// - Parameters:
    ///   - result: The `Result` from the Sign in with Apple flow.
    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user
                let fullName = appleIDCredential.fullName
                print("Apple Sign-In succeeded. User ID: \(userID), Name: \(fullName?.givenName ?? "N/A")")
                isLoggedIn = true
                showMainTabView = true
            }
        case .failure(let error):
            print("Apple Sign-In failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Footer Actions
    
    /// Handles "Terms of Service" tap (placeholder for navigation).
    func onTermsOfServiceTapped() {
        print("Terms of Service tapped")
    }
    
    /// Handles "Sign-up" tap (placeholder for navigation).
    func onSignUpTapped() {
        print("Sign-up tapped")
    }
}
