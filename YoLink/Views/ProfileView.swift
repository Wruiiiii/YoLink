import SwiftUI


struct ProfileUser {
    var name: String = "林嘉远"
    var professionalHeadline: String = "资深用户体验架构师 · Meta-X"
    var personalHeadline: String = "生活探索者 · 设计爱好者"
    var bio: String = "拥有 8+ 年以人为本的数字产品设计经验，专注于复杂系统的用户体验设计与团队协作。目前在 Meta-X 负责核心产品设计，热爱解决真实问题并创造有意义的体验。"
    var personalNote: String = "设计让生活更美好。保持好奇，持续探索，享受每一个小小的日常仪式感。"
    var connections: String = "1.2千"
    var eventsJoined: Int = 48
    var hosted: Int = 12
    var professionalTags: [String] = ["互联网", "用户体验", "产品设计"]
    var education: String = "卡内基梅隆大学"
    var expertise: [String] = ["产品策略", "界面系统", "用户研究", "设计思维", "原型设计", "团队协作"]
    var interests: [String] = ["骑行", "精品咖啡", "摄影", "旅行", "现代建筑", "阅读", "音乐", "手冲咖啡", "美食", "城市漫步"]
}

struct ProfileEvent: Identifiable {
    let id = UUID()
    var title: String
    var dateLocation: String
    var imageName: String?
}

private struct WorkUpdate: Identifiable {
    let id = UUID()
    var title: String
    var meta: String
    var imageName: String?
    var likes: Int
    var comments: Int
    var shares: Int
}

private struct LifeMoment: Identifiable {
    let id = UUID()
    var title: String
    var imageName: String?
    var systemImage: String
    var tint: Color
}


struct ProfileView: View {
    @State private var selectedFace: ProfileFace = .professional
    @State private var selectedTab: ProfileTab = .myEvents
    @State private var user = ProfileUser()
    @State private var showSettings = false
    @State private var flipRotation: Double = 0
    @GestureState private var verticalDrag: CGFloat = 0

    private let cardHeight: CGFloat = 640

    private let myEvents: [ProfileEvent] = [
        ProfileEvent(title: "产品负责人交流会 2024", dateLocation: "明天 18:30 · 上海静安", imageName: "Profile_E1"),
        ProfileEvent(title: "界面设计工作坊：高级自动布局", dateLocation: "5月12日 10:00 · 创新中心", imageName: "Profile_E2"),
    ]

    private let recommendations: [ProfileEvent] = [
        ProfileEvent(title: "设计系统峰会", dateLocation: "5月3日 14:00 · 深圳南山", imageName: "Profile_R1"),
        ProfileEvent(title: "用户研究圆桌会", dateLocation: "6月10日 09:00 · 北京朝阳", imageName: "Profile_R2"),
    ]

    private let workUpdates: [WorkUpdate] = [
        WorkUpdate(title: "正在重构核心数据看板，帮助团队更快做出产品决策。", meta: "2天前 · Meta-X", imageName: "Profile_R1", likes: 36, comments: 12, shares: 5),
        WorkUpdate(title: "今天和产品团队完成了一场很棒的设计工作坊。", meta: "1周前 · Meta-X", imageName: "Profile_R2", likes: 28, comments: 8, shares: 3),
    ]

    private let lifeMoments: [LifeMoment] = [
        LifeMoment(title: "周末骑行", imageName: nil, systemImage: "bicycle", tint: Color(hex: "6EA6D8")),
        LifeMoment(title: "晨间咖啡", imageName: "Profile_E2", systemImage: "cup.and.saucer.fill", tint: Color(hex: "B9824A")),
        LifeMoment(title: "城市日落", imageName: "Profile_R1", systemImage: "sunset.fill", tint: Color(hex: "D98A5B")),
        LifeMoment(title: "绿植角落", imageName: nil, systemImage: "camera.macro", tint: Color(hex: "7BA36A")),
    ]

    private enum ProfileFace: String, CaseIterable {
        case professional = "职业面"
        case personal = "生活面"

        var pickerTitle: String {
            switch self {
            case .professional: "职业面"
            case .personal: "生活面"
            }
        }

        var badgeTitle: String {
            switch self {
            case .professional: "职业面"
            case .personal: "生活面"
            }
        }

        var tint: Color {
            switch self {
            case .professional: Color(hex: "3D5AFE")
            case .personal: Color(hex: "FFD636")
            }
        }
    }

    private enum ProfileTab: String, CaseIterable {
        case myEvents = "过去活动"
        case recommendations = "推荐"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    profileFlipCard
                        .padding(.horizontal, 18)
                        .padding(.top, 40)

                    participationPanel
                        .padding(.top, 45)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 100)
                }
            }
            .background(pageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("我的主页")
                        .font(.headline)
                        .foregroundColor(Color(hex: "14161C"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(Color(hex: "14161C"))
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [Color(hex: "F6F7FB"), Color(hex: "E8EDFB")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var profileFlipCard: some View {
        let dragProgress = min(max(-verticalDrag / 160, 0), 1)

        return ZStack {
            professionalCard
                .rotation3DEffect(.degrees(flipRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.74)
                .opacity(flipRotation < 90 ? 1 : 0)

            personalCard
                .rotation3DEffect(.degrees(flipRotation + 180), axis: (x: 0, y: 1, z: 0), perspective: 0.74)
                .opacity(flipRotation >= 90 ? 1 : 0)
        }
        .frame(height: cardHeight)
        .scaleEffect(1 - dragProgress * 0.025)
        .overlay(alignment: .topLeading) {
            flipHintBadge
                .padding(18)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            flipToOpposite()
        }
        .gesture(
            DragGesture(minimumDistance: 16)
                .updating($verticalDrag) { value, state, _ in
                    if value.translation.height < 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    guard value.translation.height < -52 else { return }
                    flipToOpposite()
                }
        )
        .animation(.easeInOut(duration: 0.6), value: flipRotation)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: verticalDrag)
        .accessibilityHint("点击或上滑翻转主页卡片")
    }

    private var flipHintBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11, weight: .bold))
            Text(selectedFace.badgeTitle)
                .font(.caption2.weight(.bold))
        }
        .foregroundColor(selectedFace == .professional ? .white.opacity(0.82) : Color(hex: "806A20"))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            (selectedFace == .professional ? Color.white.opacity(0.12) : Color.white.opacity(0.7)),
            in: Capsule()
        )
    }

    private var professionalCard: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 6)

            avatar(size: 88, stroke: .white.opacity(0.9))

            VStack(spacing: 5) {
                nameLine(color: .white)

                Text(user.professionalHeadline)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                VStack(spacing: 4) {
                    Label(user.professionalTags.joined(separator: " / "), systemImage: "network")
                    Label(user.education, systemImage: "mappin.circle.fill")
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.78))
                .padding(.top, 4)
            }

            editButton(title: "编辑职业资料", foreground: .white, background: Color(hex: "3B5AFE"))

            VStack(alignment: .leading, spacing: 14) {
                infoBlock(title: "职业简介", text: user.bio, textColor: .white.opacity(0.88), titleColor: .white)
                chipSection(title: "核心技能", items: user.expertise, style: .professional)
                workUpdatesSection
            }
            .padding(.top, 2)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(professionalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: 16)
    }

    private var professionalBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "142253"), Color(hex: "233C83")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                Circle()
                    .fill(Color(hex: "3D5AFE").opacity(0.18))
                    .frame(width: proxy.size.width * 0.78)
                    .offset(x: -proxy.size.width * 0.32, y: proxy.size.height * 0.1)

                Circle()
                    .fill(Color.black.opacity(0.14))
                    .frame(width: proxy.size.width * 0.72)
                    .offset(x: proxy.size.width * 0.62, y: -proxy.size.height * 0.08)
            }
        }
    }

    private var personalCard: some View {
        VStack(spacing: 13) {
            ZStack {
                personalDecorations
                avatar(size: 88, stroke: Color.white.opacity(0.95))
                    .padding(.top, 18)
            }
            .frame(height: 164)

            VStack(spacing: 5) {
                Text(user.name)
                    .font(.title3.weight(.bold))
                    .foregroundColor(Color(hex: "14161C"))

                Text(user.personalHeadline)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color(hex: "7A6B3A"))
            }

            editButton(title: "编辑生活资料", foreground: Color(hex: "14161C"), background: Color(hex: "FFD636"))

            VStack(alignment: .leading, spacing: 15) {
                chipSection(title: "兴趣标签", items: user.interests, style: .personal)
                personalQuote
                lifeMomentsSection
            }
            .padding(18)
            .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(personalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 28, x: 0, y: 16)
    }

    private var personalBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "F7F8FB"), Color(hex: "ECEFF6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: -20, y: 58))
                    path.addCurve(
                        to: CGPoint(x: proxy.size.width + 20, y: 42),
                        control1: CGPoint(x: proxy.size.width * 0.32, y: 12),
                        control2: CGPoint(x: proxy.size.width * 0.66, y: 98)
                    )
                }
                .stroke(Color(hex: "FFD636").opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))

                Path { path in
                    path.move(to: CGPoint(x: 12, y: 144))
                    path.addCurve(
                        to: CGPoint(x: proxy.size.width - 18, y: 206),
                        control1: CGPoint(x: proxy.size.width * 0.22, y: 210),
                        control2: CGPoint(x: proxy.size.width * 0.74, y: 118)
                    )
                }
                .stroke(Color(hex: "FFD636").opacity(0.42), style: StrokeStyle(lineWidth: 1.2, dash: [5, 7]))
            }
        }
    }

    private var personalDecorations: some View {
        GeometryReader { proxy in
            PolaroidTile(systemImage: "cup.and.saucer.fill", rotation: -8)
                .position(x: proxy.size.width * 0.17, y: 42)

            PolaroidTile(systemImage: "camera.macro", rotation: 9)
                .position(x: proxy.size.width * 0.85, y: 96)

            PolaroidTile(systemImage: "mountain.2.fill", rotation: -7)
                .scaleEffect(0.82)
                .position(x: proxy.size.width * 0.14, y: 132)

            Text("嗨！")
                .font(.title3.weight(.medium))
                .foregroundColor(Color(hex: "9C8450"))
                .rotationEffect(.degrees(8))
                .position(x: proxy.size.width * 0.86, y: 28)

            Image(systemName: "face.smiling")
                .font(.system(size: 28, weight: .regular))
                .foregroundColor(Color(hex: "FFD636"))
                .position(x: proxy.size.width * 0.12, y: 102)
        }
    }

    private var workUpdatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("工作动态", color: .white)
                Spacer()
                seeAllButton(color: .white.opacity(0.72))
            }

            VStack(spacing: 10) {
                ForEach(workUpdates) { update in
                    workUpdateRow(update)
                }
            }
        }
    }

    private var lifeMomentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("生活瞬间", color: Color(hex: "14161C"))
                Spacer()
                seeAllButton(color: Color(hex: "7A6B3A"))
            }

            HStack(spacing: 8) {
                ForEach(lifeMoments) { moment in
                    lifeMomentTile(moment)
                }
            }
        }
    }

    private var personalQuote: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\"")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(Color(hex: "FFD636"))
                .frame(width: 24, alignment: .leading)

            Text(user.personalNote)
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color(hex: "5F542E"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("\"")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(hex: "FFD636"))
                .frame(width: 20, alignment: .trailing)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "FFD636").opacity(0.75), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
                .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
    }

    private var participationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活动参与")
                .font(.headline)
                .foregroundColor(Color(hex: "142253"))

            VStack(spacing: 16) {
                participationStats
                activityListCard
            }
            .padding(14)
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
        }
    }

    private var participationStats: some View {
        VStack(alignment: .leading, spacing: 12) {
//            Text("数据统计")
//                .font(.subheadline.weight(.semibold))
//                .foregroundColor(Color(hex: "142253"))

            HStack(spacing: 0) {
                neutralStatItem(value: user.connections, label: "人脉连接")
                neutralSeparator
                neutralStatItem(value: "\(user.eventsJoined)", label: "参与活动")
                neutralSeparator
                neutralStatItem(value: "\(user.hosted)", label: "主办活动")
            }
            .padding(.vertical, 18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
    }

    private var activityListCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("过去活动")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: "142253"))

                Spacer()

                seeAllButton(color: Color(hex: "5A6070"))
            }
            .padding(.bottom, 6)

            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Text(tab.rawValue)
                                .font(.caption.weight(selectedTab == tab ? .bold : .medium))
                                .foregroundColor(selectedTab == tab ? Color(hex: "142253") : Color(hex: "8E8E93"))

                            Rectangle()
                                .fill(selectedTab == tab ? Color(hex: "FFD636") : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)

            let events = selectedTab == .myEvents ? myEvents : recommendations
            VStack(spacing: 0) {
                ForEach(events) { event in
                    eventRow(event: event)

                    if event.id != events.last?.id {
                        Divider().padding(.leading, 70)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var neutralSeparator: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.55))
            .frame(width: 1, height: 38)
    }

    // MARK: - Actions

    private func flip(to face: ProfileFace) {
        guard selectedFace != face else { return }
        selectedFace = face
        withAnimation(.easeInOut(duration: 0.6)) {
            flipRotation = face == .professional ? 0 : 180
        }
    }

    private func flipToOpposite() {
        flip(to: selectedFace == .professional ? .personal : .professional)
    }

    // MARK: - Sub-components

    private func avatar(size: CGFloat, stroke: Color) -> some View {
        Image("ProfileHeadshot")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(stroke, lineWidth: 3))
            .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 7)
    }

    private func nameLine(color: Color) -> some View {
        HStack(spacing: 5) {
            Text(user.name)
                .font(.title3.weight(.bold))

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "3B5AFE"))
        }
        .foregroundColor(color)
    }

    private func editButton(title: String, foreground: Color, background: Color) -> some View {
        Button {
            // TODO: wire to edit-profile flow when the form exists.
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(background, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func infoBlock(title: String, text: String, textColor: Color, titleColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle(title, color: titleColor)

            Text(text)
                .font(.footnote)
                .foregroundColor(textColor)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chipSection(title: String, items: [String], style: ChipStyle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title, color: style == .professional ? .white : Color(hex: "14161C"))
            chipGrid(items: items, style: style)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundColor(color)
    }

    private enum ChipStyle { case professional, personal }

    private func chipGrid(items: [String], style: ChipStyle) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(style == .professional ? .white : Color(hex: "5F542E"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        style == .professional
                            ? Color(hex: "3B5AFE").opacity(0.72)
                            : Color(hex: "FFF2CC")
                    )
                    .clipShape(Capsule())
            }
        }
    }

    private func workUpdateRow(_ update: WorkUpdate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let imageName = update.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(hex: "3B5AFE")
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(update.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(update.meta)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.72))

                HStack(spacing: 14) {
                    metricLabel(systemImage: "hand.thumbsup", value: update.likes, color: .white.opacity(0.82))
                    metricLabel(systemImage: "bubble.left", value: update.comments, color: .white.opacity(0.82))
                    metricLabel(systemImage: "arrowshape.turn.up.right", value: update.shares, color: .white.opacity(0.82))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func lifeMomentTile(_ moment: LifeMoment) -> some View {
        ZStack {
            Group {
                if let imageName = moment.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [moment.tint.opacity(0.92), moment.tint.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: moment.systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel(moment.title)
    }

    private func eventRow(event: ProfileEvent) -> some View {
        HStack(spacing: 12) {
            Group {
                if let name = event.imageName {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(hex: "D0D5F5")
                        Image(systemName: "photo")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "142253").opacity(0.65))
                    }
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .lineLimit(2)

                Text(event.dateLocation)
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "C7C7CC"))
        }
        .padding(.vertical, 12)
    }

    private func neutralStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(Color(hex: "14161C"))

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(Color(hex: "5A6070"))
        }
        .frame(maxWidth: .infinity)
    }

    private func metricLabel(systemImage: String, value: Int, color: Color) -> some View {
        Label("\(value)", systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundColor(color)
    }

    private func seeAllButton(color: Color) -> some View {
        Button {
            // TODO: wire to full activity list.
        } label: {
            Label("查看全部", systemImage: "chevron.right")
                .labelStyle(.titleAndIcon)
                .font(.caption2.weight(.semibold))
                .foregroundColor(color)
        }
        .buttonStyle(.plain)
    }

    private func selectedTextColor(for face: ProfileFace) -> Color {
        .white
    }
}

// MARK: - Decorative Tile

private struct PolaroidTile: View {
    let systemImage: String
    let rotation: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.16), radius: 7, x: 0, y: 4)

            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color(hex: "9C8450"))
                .frame(width: 42, height: 36)
                .background(Color(hex: "F5E5C6"), in: RoundedRectangle(cornerRadius: 3))
                .padding(.bottom, 10)
        }
        .frame(width: 56, height: 64)
        .rotationEffect(.degrees(rotation))
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
        .environmentObject(AppSessionViewModel())
}
