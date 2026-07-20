import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var session: AppSessionViewModel

    var body: some View {
        RegistrationFlowView {
            session.isLoggedIn = true
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AppSessionViewModel())
    }
}
