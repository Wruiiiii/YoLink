import SwiftUI

/// Navigation container that holds Login → Sign Up flow.
/// Keeps AuthViewModel (for Apple/Google/phone mock)
/// and our real backend ViewModels separate and clean.
struct AuthFlowView: View {

    @EnvironmentObject var session: AppSessionViewModel

    // Existing mock view model for Apple / Google / phone UI
    @State private var authViewModel = AuthViewModel()

    // Controls navigation to the real email sign-up screen
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            LoginView(
                viewModel: authViewModel,
                onSignUpTapped: { showSignUp = true },
                onLoginSucceeded: { session.isLoggedIn = true }
            )
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
        }
        // When mock auth succeeds (Apple/Google/phone), mirror into session
        .onChange(of: authViewModel.showMainTabView) { _, loggedIn in
            if loggedIn { session.isLoggedIn = true }
        }
    }
}
