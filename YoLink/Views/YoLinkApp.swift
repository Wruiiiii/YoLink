import SwiftUI

@main
struct YoLinkApp: App {

    @StateObject private var session = AppSessionViewModel()
    @State private var showSplash = true
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView(isActive: $showSplash)
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environmentObject(session)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showSplash)
            // ← restoreSession runs during the 2s splash window
            // so by the time ContentView appears, isLoggedIn is already set
            .task { await session.restoreSession() }
        }
    }
}
