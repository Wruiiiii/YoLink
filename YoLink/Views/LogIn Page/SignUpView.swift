import SwiftUI

struct SignUpView: View {
    var body: some View {
        RegistrationFlowView()
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AppSessionViewModel())
    }
}
