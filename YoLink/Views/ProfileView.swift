import SwiftUI

// Profile Data Model

struct ProfileUser {
    var name: String = "Jordan Miller"
    var headline: String = "Senior UX Architect at Meta-X"
    var bio: String = "Crafting human-centered digital experiences for over 8 years. Recently relocated to Berlin and excited to meet local designers, product managers, and creative techies. Let's talk system design and urban mobility!"
    var connections: String = "1.2k"
    var eventsJoined: Int = 48
    var hosted: Int = 12
    var expertise: [String] = ["Product Strategy", "UI Systems", "User Research", "Leadership"]
    var interests: [String] = ["Biking", "Specialty Coffee", "Modern Architecture", "Fine Dining"]
}

struct ProfileEvent: Identifiable {
    let id = UUID()
    var title: String
    var dateLocation: String
    var imageName: String?
}

//  Main ProfileView

struct ProfileView: View {
    @State private var selectedTab: ProfileTab = .myEvents
    @State private var user = ProfileUser()

    private let myEvents: [ProfileEvent] = [
        ProfileEvent(title: "Product Lead Mixer 2024", dateLocation: "Tomorrow, 18:30 • Berlin Mitte", imageName: "Profile_E1"),
        ProfileEvent(title: "UI Workshop: Advanced Auto Layout", dateLocation: "May 12, 10:00 • Tech Hub", imageName: "Profile_E2"),
    ]

    private let recommendations: [ProfileEvent] = [
        ProfileEvent(title: "Design Systems Summit", dateLocation: "May 3, 14:00 • Kreuzberg",imageName: "Profile_R1"),
        ProfileEvent(title: "UX Research Roundtable", dateLocation: "June 10, 09:00 • Mitte",imageName: "Profile_R2"),
    ]

    enum ProfileTab: String, CaseIterable {
        case myEvents = "My Events"
        case recommendations = "Recommendations"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // Avatar + Name + Headline
                    VStack(spacing: 12) {
                        // Avatar
                        Image("ProfileHeadshot")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 114, height: 114)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                            .padding(.top, 30)

                        VStack(spacing: 4) {
                            Text(user.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text(user.headline)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "2C4397"))
                        }

                        // Edit Profile button
                        Button {} label: {
                            Text("Edit Profile")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "FECD70"), Color(hex: "FECD70")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 4)
                    }
                    .padding(.bottom, 20)

                    // MARK: Stats Row
                    HStack(spacing: 0) {
                        statItem(value: user.connections, label: "CONNECTIONS")
                        Divider().frame(height: 36)
                        statItem(value: "\(user.eventsJoined)", label: "EVENTS JOINED")
                        Divider().frame(height: 36)
                        statItem(value: "\(user.hosted)", label: "HOSTED")
                    }
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 35))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 28)

                    // MARK: Professional Bio
                    sectionBlock {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Professional Bio")
                            Text(user.bio)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "3A3A3A"))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // MARK: Core Expertise
                    sectionBlock {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Core Expertise")
                            chipGrid(items: user.expertise, style: .expertise)
                        }
                    }

                    // MARK: Interests
                    sectionBlock {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Interests")
                            chipGrid(items: user.interests, style: .interests)
                        }
                    }.padding(.bottom, 18)

                    // MARK: Tabbed Events Section
                    VStack(spacing: 0) {
                        // Tab bar
                        HStack(spacing: 0) {
                            ForEach(ProfileTab.allCases, id: \.self) { tab in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedTab = tab
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        Text(tab.rawValue)
                                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                                            .foregroundColor(selectedTab == tab ? Color(hex: "FECD70") : Color(hex: "8E8E93"))
                                        Rectangle()
                                            .fill(selectedTab == tab ? Color(hex: "FECD70") : Color.clear)
                                            .frame(height: 2)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 30)

                        Divider()

                        // Event rows
                        let events = selectedTab == .myEvents ? myEvents : recommendations
                        VStack(spacing: 0) {
                            ForEach(events) { event in
                                eventRow(event: event)
                                if event.id != events.last?.id {
                                    Divider().padding(.leading, 96)
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(Color(hex: "F2F3F8"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }
                }
            }
        }
    }

    // MARK: - Sub-components

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "8E8E93"))
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(Color(hex: "1A1A1A"))
    }

    @ViewBuilder
    private func sectionBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.bottom, 24)
    }

    enum ChipStyle { case expertise, interests }

    private func chipGrid(items: [String], style: ChipStyle) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(style == .expertise ? Color(hex: "000000") : Color(hex: "1A1A1A"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        style == .expertise
                            ? Color(hex: "E6E9F8")
                            : Color(hex: "EFEFEF")
                    )
                    .clipShape(Capsule())
            }
        }
    }

    private func eventRow(event: ProfileEvent) -> some View {
        HStack(spacing: 16) {
            // Circle thumbnail
            Group {
                if let name = event.imageName {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(hex: "D0D5F5")
                        Image(systemName: "photo")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "FECD70").opacity(0.5))
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())

            // Text
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .lineLimit(2)
                Text(event.dateLocation)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "C7C7CC"))
        }
        .padding(.vertical, 18)
        .background(Color(hex: "F2F3F8"))
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Color Helper

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

#Preview {
    ProfileView()
}


//
//import SwiftUI
//
//// MARK: - Profile Data Model
//
//struct ProfileUser {
//    var name: String = "Jordan Miller"
//    var headline: String = "Senior UX Architect at Meta-X"
//    var bio: String = "Crafting human-centered digital experiences for over 8 years. Recently relocated to Berlin and excited to meet local designers, product managers, and creative techies. Let's talk system design and urban mobility!"
//    var connections: String = "1.2k"
//    var eventsJoined: Int = 48
//    var hosted: Int = 12
//    var expertise: [String] = ["Product Strategy", "UI Systems", "User Research", "Leadership"]
//    var interests: [String] = ["Biking", "Specialty Coffee", "Modern Architecture", "Fine Dining"]
//}
//
//struct ProfileEvent: Identifiable {
//    let id = UUID()
//    var title: String
//    var dateLocation: String
//    var imageName: String?
//}
//
//// MARK: - Main ProfileView
//
//struct ProfileView: View {
//    @State private var selectedTab: ProfileTab = .myEvents
//    @State private var user = ProfileUser()
//
//    private let myEvents: [ProfileEvent] = [
//        ProfileEvent(title: "Product Lead Mixer 2024", dateLocation: "Tomorrow, 18:30 • Berlin Mitte", imageName: "Profile_E1"),
//        ProfileEvent(title: "UI Workshop: Advanced Auto Layout", dateLocation: "May 12, 10:00 • Tech Hub", imageName: "Profile_E2"),
//    ]
//
//    private let recommendations: [ProfileEvent] = [
//        ProfileEvent(title: "Design Systems Summit", dateLocation: "May 3, 14:00 • Kreuzberg"),
//        ProfileEvent(title: "UX Research Roundtable", dateLocation: "June 10, 09:00 • Mitte"),
//    ]
//
//    enum ProfileTab: String, CaseIterable {
//        case myEvents = "My Events"
//        case recommendations = "Recommendations"
//    }
//
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 0) {
//
//                    // MARK: Avatar + Name + Headline
//                    VStack(spacing: 12) {
//                        // Avatar
//                        Image("ProfileHeadshot")
//                            .resizable()
//                            .scaledToFill()
//                            .frame(width: 114, height: 114)
//                            .clipShape(Circle())
//                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
//                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
//                            .padding(.top, 30)
//
//                        VStack(spacing: 4) {
//                            Text(user.name)
//                                .font(.system(size: 24, weight: .bold))
//                                .foregroundColor(Color(hex: "1A1A1A"))
//
//                            Text(user.headline)
//                                .font(.system(size: 16))
//                                .foregroundColor(Color(hex: "2C4397"))
//                        }
//
//                        // Edit Profile button
//                        Button {} label: {
//                            Text("Edit Profile")
//                                .font(.system(size: 16, weight: .semibold))
//                                .foregroundColor(.white)
//                                .frame(maxWidth: .infinity)
//                                .frame(height: 55)
//                                .background(
//                                    LinearGradient(
//                                        colors: [Color(hex: "7B8FF7"), Color(hex: "FECD70")],
//                                        startPoint: .leading,
//                                        endPoint: .trailing
//                                    )
//                                )
//                                .clipShape(Capsule())
//                        }
//                        .padding(.horizontal, 30)
//                        .padding(.top, 4)
//                    }
//                    .padding(.bottom, 20)
//
//                    // MARK: Stats Row
//                    HStack(spacing: 0) {
//                        statItem(value: user.connections, label: "CONNECTIONS")
//                        Divider().frame(height: 36)
//                        statItem(value: "\(user.eventsJoined)", label: "EVENTS JOINED")
//                        Divider().frame(height: 36)
//                        statItem(value: "\(user.hosted)", label: "HOSTED")
//                    }
//                    .padding(.vertical, 18)
//                    .background(Color.white)
//                    .clipShape(RoundedRectangle(cornerRadius: 35))
//                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
//                    .padding(.horizontal, 30)
//                    .padding(.bottom, 28)
//
//                    // MARK: Professional Bio
//                    sectionBlock {
//                        VStack(alignment: .leading, spacing: 10) {
//                            sectionTitle("Professional Bio")
//                            Text(user.bio)
//                                .font(.system(size: 15))
//                                .foregroundColor(Color(hex: "3A3A3A"))
//                                .lineSpacing(5)
//                                .fixedSize(horizontal: false, vertical: true)
//                        }
//                    }
//
//                    // MARK: Core Expertise
//                    sectionBlock {
//                        VStack(alignment: .leading, spacing: 12) {
//                            sectionTitle("Core Expertise")
//                            chipGrid(items: user.expertise, style: .expertise)
//                        }
//                    }
//
//                    // MARK: Interests
//                    sectionBlock {
//                        VStack(alignment: .leading, spacing: 12) {
//                            sectionTitle("Interests")
//                            chipGrid(items: user.interests, style: .interests)
//                        }
//                    }.padding(.bottom,18)
//
//                    // MARK: Tabbed Events Section
//                    VStack(spacing: 0) {
//                        // Tab bar
//                        HStack(spacing: 0) {
//                            ForEach(ProfileTab.allCases, id: \.self) { tab in
//                                Button {
//                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                        selectedTab = tab
//                                    }
//                                } label: {
//                                    VStack(spacing: 8) {
//                                        Text(tab.rawValue)
//                                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
//                                            .foregroundColor(selectedTab == tab ? Color(hex: "FECD70") : Color(hex: "8E8E93"))
//                                        Rectangle()
//                                            .fill(selectedTab == tab ? Color(hex: "FECD70") : Color.clear)
//                                            .frame(height: 2)
//                                    }
//                                }
//                                .frame(maxWidth: .infinity)
//                                .buttonStyle(.plain)
//                            }
//                        }
//                        .padding(.horizontal, 30)
//
//                        Divider()
//
//                        // Event rows
//                        let events = selectedTab == .myEvents ? myEvents : recommendations
//                        VStack(spacing: 0) {
//                            ForEach(events) { event in
//                                eventRow(event: event)
//                                if event.id != events.last?.id {
//                                    Divider().padding(.leading, 96)
//                                }
//                            }
//                        }
//                        .padding(.horizontal, 30)
//                    }
//                    .padding(.bottom, 100)
//                }
//            }
//            .background(Color(hex: "F2F3F8"))
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .principal) {
//                    Text("Profile")
//                        .font(.system(size: 20, weight: .bold))
//                        .foregroundColor(Color(hex: "1A1A1A"))
//                }
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button {} label: {
//                        Image(systemName: "gearshape.fill")
//                            .font(.system(size: 20))
//                            .foregroundColor(Color(hex: "1A1A1A"))
//                    }
//                }
//            }
//        }
//    }
//
//    // MARK: - Sub-components
//
//    private func statItem(value: String, label: String) -> some View {
//        VStack(spacing: 4) {
//            Text(value)
//                .font(.system(size: 22, weight: .bold))
//                .foregroundColor(Color(hex: "1A1A1A"))
//            Text(label)
//                .font(.system(size: 10, weight: .medium))
//                .foregroundColor(Color(hex: "8E8E93"))
//                .tracking(0.3)
//        }
//        .frame(maxWidth: .infinity)
//    }
//
//    private func sectionTitle(_ text: String) -> some View {
//        Text(text)
//            .font(.system(size: 18, weight: .bold))
//            .foregroundColor(Color(hex: "1A1A1A"))
//    }
//
//    @ViewBuilder
//    private func sectionBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
//        VStack(alignment: .leading, spacing: 0) {
//            content()
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(.horizontal, 30)
//        .padding(.bottom, 24)
//    }
//
//    enum ChipStyle { case expertise, interests }
//
//    private func chipGrid(items: [String], style: ChipStyle) -> some View {
//        // Wrap chips manually using a flow-like layout
//        let columns = [GridItem(.flexible()), GridItem(.flexible())]
//        return LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
//            ForEach(items, id: \.self) { item in
//                Text(item)
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundColor(style == .expertise ? Color(hex: "FECD70") : Color(hex: "1A1A1A"))
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 14)
//                    .frame(maxWidth: .infinity)
//                    .background(
//                        style == .expertise
//                            ? Color(hex: "EEF0FD")
//                            : Color(hex: "EFEFEF")
//                    )
//                    .clipShape(Capsule())
//            }
//        }
//    }
//
//    private func eventRow(event: ProfileEvent) -> some View {
//        HStack(spacing: 16) {
//            // Circle thumbnail
//            Group {
//                if let name = event.imageName {
//                    Image(name)
//                        .resizable()
//                        .scaledToFill()
//                } else {
//                    ZStack {
//                        Color(hex: "D0D5F5")
//                        Image(systemName: "photo")
//                            .font(.system(size: 22))
//                            .foregroundColor(Color(hex: "FECD70").opacity(0.5))
//                    }
//                }
//            }
//            .frame(width: 64, height: 64)
//            .clipShape(Circle())
//
//            // Text
//            VStack(alignment: .leading, spacing: 5) {
//                Text(event.title)
//                    .font(.system(size: 15, weight: .semibold))
//                    .foregroundColor(Color(hex: "1A1A1A"))
//                    .lineLimit(2)
//                Text(event.dateLocation)
//                    .font(.system(size: 13))
//                    .foregroundColor(Color(hex: "8E8E93"))
//            }
//
//            Spacer()
//
//            Image(systemName: "chevron.right")
//                .font(.system(size: 14, weight: .medium))
//                .foregroundColor(Color(hex: "C7C7CC"))
//        }
//        .padding(.vertical, 18)
//        .background(Color(hex: "F2F3F8"))
//    }
//}
//
//// MARK: - Color Helper
//
//private extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let r = Double((int >> 16) & 0xFF) / 255
//        let g = Double((int >> 8) & 0xFF) / 255
//        let b = Double(int & 0xFF) / 255
//        self.init(.sRGB, red: r, green: g, blue: b)
//    }
//}
//
//#Preview {
//    ProfileView()
//}
