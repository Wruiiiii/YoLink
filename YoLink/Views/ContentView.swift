
import SwiftUI

struct ContentView: View {

    @EnvironmentObject var session: AppSessionViewModel

    var body: some View {
        Group {
            if session.isLoggedIn {
                MainTabView()
            } else {
                AuthFlowView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.isLoggedIn)
    }
}
