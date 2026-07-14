import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .group
    @State private var showCreateEventSheet = false
    @State private var showCreateGroupEvent = false
    @State private var events: [EventItem] = []

    enum Tab: Int, CaseIterable {
        case group    = 0
        case connect  = 1
        case calendar = 2
        case profile  = 3
    }

    var body: some View {
        ZStack {

            // MARK: - TabView
            TabView(selection: $selectedTab) {

                HomeView(events: $events)
                    .tag(Tab.group.rawValue)
                    .tabItem {
                        Label("活动", systemImage: "person.3")
                    }

                SocialView()
                    .tag(Tab.connect.rawValue)
                    .tabItem {
                        Label("社交", systemImage: "person.2.fill")
                    }

                // ← CalendarView now wired here
                CalendarView()
                    .tag(Tab.calendar.rawValue)
                    .tabItem {
                        Label("日程", systemImage: "calendar")
                    }

                ProfileView()
                    .tag(Tab.profile.rawValue)
                    .tabItem {
                        Label("我的", systemImage: "person.fill")
                    }
            }
            .tint(Color("Theme"))

            // MARK: - Center FAB
            VStack {
                Spacer()
                Button {
                    showCreateEventSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color("Theme").opacity(0.25))
                            .frame(width: 70, height: 70)
                        Circle()
                            .fill(Color("Theme"))
                            .frame(width: 58, height: 58)
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 70, height: 70)
                }
                .buttonStyle(.plain)
                .offset(y: -20)
            }
        }
        .sheet(isPresented: $showCreateEventSheet) {
            CreateActionSheetView {
                showCreateEventSheet = false
                showCreateGroupEvent = true
            }
            .presentationDetents([.height(476), .medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showCreateGroupEvent) {
            NavigationStack {
                CreateGroupEventView(events: $events)
            }
        }
    }
}

// MARK: - Placeholder tabs

private struct PlaceholderTabView: View {
    let title: String
    let icon: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(Color("Theme"))
                Text(title)
                    .font(.title2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "F5F6F8"))
        }
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

#Preview {
    MainTabView()
}
