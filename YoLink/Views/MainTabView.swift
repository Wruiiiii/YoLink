import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .group
    @State private var showCreateEventSheet = false
    @State private var showCreateGroupEvent = false
    @State private var events: [EventItem] = [
        EventItem(name: "Tech Founders & VC Mixer: Downtown Hub", location: "Skyline Lounge, Austin TX", date: Date()),
        EventItem(name: "Creative Minds: Design Meetup", location: "WeWork Downtown, Austin TX", date: Date())
    ]
    
    enum Tab: Int, CaseIterable {
        case group = 0
        case connect = 1
        case create = 2   // Center FAB (blank tab)
        case calendar = 3
        case profile = 4
    }
    
    var body: some View {
        ZStack {
            // MARK: - TabView (Bottom Layer)
            TabView(selection: $selectedTab) {
                HomeView(events: $events)
                    .tag(Tab.group.rawValue)
                    .tabItem {
                        Label("Group", systemImage: "person.3")
                    }
                
                PlaceholderTabView(title: "1:1 Connect", icon: "hand.wave")
                    .tag(Tab.connect.rawValue)
                    .tabItem {
                        Label("1:1 Connect", systemImage: "hand.wave")
                    }
                
                // Hidden/blank tab for center FAB space
//                Color.clear
//                    .tag(Tab.create.rawValue)
//                    .tabItem {
//                        Label(" ", systemImage: "circle")
//                    }
                
                PlaceholderTabView(title: "Calendar", icon: "calendar")
                    .tag(Tab.calendar.rawValue)
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
                
                ProfileView()
                    .tag(Tab.profile.rawValue)
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
            }
            .tint(Color("Theme"))
            
            // MARK: - Custom Center FAB (Top Layer)
            VStack {
                Spacer()
                
                Button {
                    showCreateEventSheet = true
                } label: {
                    ZStack {
                        // Outer halo effect (semi-transparent purple)
                        Circle()
                            .fill(Color("Theme").opacity(0.25))
                            .frame(width: 70, height: 70)
                        
                        // Primary solid purple circle
                        Circle()
                            .fill(Color("Theme"))
                            .frame(width: 58, height: 58)
                        
                        // Plus icon
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
                // Dismiss sheet and present full-screen Create Group Event page
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

// MARK: - Placeholder for tabs not yet implemented

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
