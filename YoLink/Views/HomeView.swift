import SwiftUI

struct HomeView: View {
    @Binding var events: [EventItem]

    @State private var searchText = ""
    @State private var selectedCategory = "全部"

    @MainActor private var popularEvents: [HomeEvent] {
        HomeEvent.demoPopular + events.map(HomeEvent.init)
    }

    @MainActor private var filteredEvents: [HomeEvent] {
        let allEvents = HomeEvent.demoAll + events.map(HomeEvent.init)
        let categoryFiltered = selectedCategory == "全部"
            ? allEvents
            : allEvents.filter { $0.category == selectedCategory }

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return categoryFiltered
        }

        return categoryFiltered.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.location.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                HomeTheme.background
                    .ignoresSafeArea()

                HomeTheme.yellow
                    .frame(height: HomeLayout.heroHeight)
                    .ignoresSafeArea(edges: .top)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HomeHeroView(searchText: $searchText)
                            .frame(height: HomeLayout.heroHeight)

                        SectionHeader(title: "热门活动", action: "查看全部")
                            .padding(.horizontal, HomeLayout.pagePadding)
                            .padding(.top, 0)

                        PopularEventsCarousel(events: popularEvents)
                            .padding(.top, 20)

                        CategorySection(selectedCategory: $selectedCategory)
                            .padding(.top, 12)

                        AllEventsSection(events: filteredEvents)
                            .padding(.top, 26)
                            .padding(.bottom, 96)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Hero

private struct HomeHeroView: View {
    @Binding var searchText: String

    var body: some View {
        ZStack(alignment: .top) {
            CurvedHeroShape(curveDepth: HomeLayout.curveDepth)
                .fill(HomeTheme.yellow)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 18) {
                HStack(alignment: .center) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(.white.opacity(0.94))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text("R")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(HomeTheme.navy)
                            )
                            .shadow(color: HomeTheme.navy.opacity(0.08), radius: 12, x: 0, y: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("欢迎回来")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(HomeTheme.navy.opacity(0.66))

                            Text("Rae Wang")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(HomeTheme.navy)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 18)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("当前位置")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(HomeTheme.navy.opacity(0.36))

                        HStack(spacing: 4) {
                            Text("库比提诺, CA")
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "location.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(HomeTheme.navy.opacity(0.74))
                    }
                }
                .padding(.horizontal, HomeLayout.pagePadding)

                HStack(spacing: 12) {
                    HomeSearchBar(text: $searchText)

                    Button {
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(HomeTheme.navy)
                            .frame(width: 58, height: 58)
                            .background(.white.opacity(0.88), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.66), lineWidth: 1))
                            .shadow(color: HomeTheme.navy.opacity(0.12), radius: 16, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("筛选")
                }
                .padding(.horizontal, HomeLayout.pagePadding)
            }
            .padding(.top, 48)
        }
    }
}

private struct CurvedHeroShape: Shape {
    var curveDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let edgeY = rect.maxY - curveDepth * 0.44
        let centerY = rect.maxY - curveDepth

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: edgeY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: edgeY),
            control1: CGPoint(x: rect.maxX * 0.72, y: centerY),
            control2: CGPoint(x: rect.maxX * 0.28, y: centerY)
        )
        path.closeSubpath()
        return path
    }
}

private struct HomeSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(HomeTheme.muted)

            TextField("搜索感兴趣的活动", text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(HomeTheme.navy)
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(HomeTheme.muted.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(.white.opacity(0.88), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: HomeTheme.navy.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Popular carousel

private struct PopularEventsCarousel: View {
    let events: [HomeEvent]

    var body: some View {
        GeometryReader { outer in
            let cardWidth = min(outer.size.width * 0.72, 292)
            let sideMargin = max((outer.size.width - cardWidth) / 2, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: HomeLayout.cardSpacing) {
                    ForEach(events) { event in
                        GeometryReader { cardProxy in
                            let midX = cardProxy.frame(in: .named("popularCarousel")).midX
                            let center = outer.size.width / 2
                            let distance = abs(midX - center)
                            let progress = min(distance / center, 1)

                            PopularEventCard(event: event, isCompact: progress > 0.42)
                                .modifier(CarouselCardModifier(progress: progress))
                        }
                        .frame(width: cardWidth, height: HomeLayout.carouselCardHeight + 70)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, sideMargin)
                .padding(.vertical, 8)
            }
            .coordinateSpace(name: "popularCarousel")
            .scrollTargetBehavior(.viewAligned)
        }
        .frame(height: HomeLayout.carouselHeight)
    }
}

private struct CarouselCardModifier: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        let eased = progress * progress
        let scale = 1 - min(progress * 0.14, 0.18)
        let verticalOffset = eased * 48
        let opacity = 1 - min(progress * 0.18, 0.24)
        let rotation = (progress == 0 ? 0 : progress * 1.6)

        content
            .scaleEffect(scale)
            .offset(y: verticalOffset)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .shadow(color: HomeTheme.navy.opacity(0.10 + (1 - progress) * 0.10), radius: 18 + (1 - progress) * 12, x: 0, y: 12)
            .animation(.spring(response: 0.42, dampingFraction: 0.84), value: progress)
    }
}

private struct PopularEventCard: View {
    let event: HomeEvent
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                EventImage(event: event)
                    .frame(height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                HStack(alignment: .top) {
                    Text(event.category)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(HomeTheme.navy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(HomeTheme.yellow, in: Capsule())

                    Spacer()

                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "FF7F4D"))
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.88), in: Circle())
                }
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 11) {
                Text(event.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(HomeTheme.navy)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label(event.dateText, systemImage: "calendar")
                    Label(event.location, systemImage: "location.fill")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(HomeTheme.muted)
                .lineLimit(1)

                HStack(spacing: 12) {
                    AvatarCluster()

                    Text("\(event.attendeeCount) 人已报名")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(HomeTheme.muted)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Button {
                    } label: {
                        Text("报名")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, isCompact ? 15 : 20)
                            .padding(.vertical, 10)
                            .background(HomeTheme.navy, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: HomeLayout.carouselCardHeight)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 1)
        )
    }
}

private struct AvatarCluster: View {
    private var colors: [Color] {
        [Color(hex: "FFD636"), Color(hex: "FF7F4D"), Color(hex: "2BC5BB")]
    }

    var body: some View {
        HStack(spacing: -7) {
            ForEach(colors.indices, id: \.self) { index in
                Circle()
                    .fill(colors[index])
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
    }
}

private struct EventImage: View {
    let event: HomeEvent

    var body: some View {
        ZStack {
            if let coverImage = event.coverImage {
                coverImage
                    .resizable()
                    .scaledToFill()
            } else if let imageName = event.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [HomeTheme.yellow.opacity(0.9), HomeTheme.navy.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "sparkles")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .clipped()
    }
}

// MARK: - Categories

private struct CategorySection: View {
    @Binding var selectedCategory: String

    private let categories: [(String, String)] = [
        ("全部", "square.grid.2x2"),
        ("金融", "chart.line.uptrend.xyaxis"),
        ("科技", "cpu"),
        ("艺术", "paintpalette"),
        ("教育", "graduationcap"),
        ("体育", "sportscourt"),
        ("创业", "lightbulb"),
        ("社交", "person.2")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("按类别探索")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HomeTheme.navy)
                .padding(.horizontal, HomeLayout.pagePadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.0) { category, icon in
                        EventCategoryChip(
                            title: category,
                            icon: icon,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                .padding(.horizontal, HomeLayout.pagePadding)
                .padding(.vertical, 4)
            }
        }
    }
}

private struct EventCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(isSelected ? HomeTheme.navy : HomeTheme.navy.opacity(0.72))
            .padding(.horizontal, 17)
            .frame(height: 42)
            .background(isSelected ? HomeTheme.yellow : .white, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? HomeTheme.yellow.opacity(0) : HomeTheme.navy.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: HomeTheme.navy.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 14 : 8, x: 0, y: isSelected ? 8 : 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All events

private struct AllEventsSection: View {
    let events: [HomeEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "全部活动", action: "查看全部")
                .padding(.horizontal, HomeLayout.pagePadding)

            LazyVStack(spacing: 12) {
                ForEach(events) { event in
                    EventListRow(event: event)
                }
            }
            .padding(.horizontal, HomeLayout.pagePadding)
        }
    }
}

private struct EventListRow: View {
    let event: HomeEvent

    var body: some View {
        HStack(spacing: 14) {
            EventImage(event: event)
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(HomeTheme.navy)
                    .lineLimit(2)

                Label(event.dateText, systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(HomeTheme.muted)

                Label(event.location, systemImage: "location.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(HomeTheme.muted)
                    .lineLimit(1)

                Text(event.category)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(HomeTheme.navy)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(HomeTheme.yellow.opacity(0.72), in: Capsule())
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 12) {
                Text(event.price)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(event.price == "免费" ? Color(hex: "16BFA3") : Color(hex: "FF7F4D"))

                Button {
                } label: {
                    Text("报名")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(HomeTheme.navy, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: HomeTheme.navy.opacity(0.06), radius: 14, x: 0, y: 7)
    }
}

private struct SectionHeader: View {
    let title: String
    let action: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HomeTheme.navy)

            Spacer()

            Button {
            } label: {
                Text(action)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HomeTheme.navy)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Data

private struct HomeEvent: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let dateText: String
    let location: String
    let price: String
    let imageName: String?
    let coverImage: Image?
    let attendeeCount: Int

    init(
        title: String,
        category: String,
        dateText: String,
        location: String,
        price: String,
        imageName: String?,
        coverImage: Image? = nil,
        attendeeCount: Int
    ) {
        self.title = title
        self.category = category
        self.dateText = dateText
        self.location = location
        self.price = price
        self.imageName = imageName
        self.coverImage = coverImage
        self.attendeeCount = attendeeCount
    }

    init(event: EventItem) {
        self.title = event.name
        self.category = "社交"
        self.dateText = HomeDateFormatter.string(from: event.date)
        self.location = event.location.isEmpty ? "地点待定" : event.location
        self.price = "免费"
        self.imageName = nil
        self.coverImage = event.coverImage
        self.attendeeCount = 12
    }

    static let demoPopular: [HomeEvent] = [
        HomeEvent(title: "当代艺术主题展览", category: "艺术", dateText: "10月19日 10:00", location: "城市艺术馆", price: "免费", imageName: "CardBG3", attendeeCount: 56),
        HomeEvent(title: "未来教育创新论坛", category: "教育", dateText: "10月18日 14:00", location: "城市创新中心", price: "免费", imageName: "CardBG4", attendeeCount: 48),
        HomeEvent(title: "金融科技行业交流会", category: "金融", dateText: "10月15日 19:00", location: "创业中心", price: "¥10", imageName: "CardBG2", attendeeCount: 64),
        HomeEvent(title: "人工智能研究工作坊", category: "科技", dateText: "10月17日 18:30", location: "城市创新中心", price: "免费", imageName: "CardBG1", attendeeCount: 38),
        HomeEvent(title: "周末城市足球赛", category: "体育", dateText: "10月20日 16:30", location: "滨河体育公园", price: "¥30", imageName: "CardBG5", attendeeCount: 72)
    ]

    static let demoAll: [HomeEvent] = [
        HomeEvent(title: "Google 人工智能研究工作坊", category: "科技", dateText: "10月17日 18:30", location: "城市创新中心", price: "免费", imageName: "CardBG1", attendeeCount: 38),
        HomeEvent(title: "金融科技行业交流会", category: "金融", dateText: "10月15日 19:00", location: "创业中心", price: "¥10", imageName: "CardBG2", attendeeCount: 64),
        HomeEvent(title: "当代艺术主题展览", category: "艺术", dateText: "10月19日 10:00", location: "城市艺术馆", price: "免费", imageName: "CardBG3", attendeeCount: 56),
        HomeEvent(title: "未来教育创新论坛", category: "教育", dateText: "10月18日 14:00", location: "城市创新中心", price: "免费", imageName: "CardBG4", attendeeCount: 48),
        HomeEvent(title: "周末城市足球赛", category: "体育", dateText: "10月20日 16:30", location: "滨河体育公园", price: "¥30", imageName: "CardBG5", attendeeCount: 72)
    ]
}

private enum HomeDateFormatter {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Style

private enum HomeLayout {
    static let pagePadding: CGFloat = 26
    static let heroHeight: CGFloat = 252
    static let curveDepth: CGFloat = 42
    static let carouselHeight: CGFloat = 356
    static let carouselCardHeight: CGFloat = 292
    static let cardSpacing: CGFloat = 22
}

private enum HomeTheme {
    static let yellow = Color(hex: "FFD636")
    static let navy = Color(hex: "232253")
    static let background = Color(hex: "F8F8F3")
    static let muted = Color(hex: "7A7D89")
}

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
    HomeView(events: .constant([
        EventItem(
            name: "创业者早餐会",
            location: "市中心咖啡馆",
            date: Date(),
            hostedBy: "Rae Wang"
        )
    ]))
}
