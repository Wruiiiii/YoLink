import SwiftUI

struct ProfileCardModel: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let introduction: String
    let identity: String
    let followerCount: String
    let projectCount: String
    let imageName: String
}

enum ProfileCardMockData {
    static let cards: [ProfileCardModel] = [
        ProfileCardModel(
            name: "林知夏",
            introduction: "产品设计师，关注人与科技之间更自然的连接。",
            identity: "体验设计师 · 上海",
            followerCount: "1,286",
            projectCount: "48",
            imageName: "Pcard1"
        ),
        ProfileCardModel(
            name: "周予安",
            introduction: "独立摄影师，用影像记录城市里柔软的瞬间。",
            identity: "摄影创作者 · 北京",
            followerCount: "2.4万",
            projectCount: "72",
            imageName: "Pcard2"
        ),
        ProfileCardModel(
            name: "陈若宁",
            introduction: "品牌策略顾问，喜欢把复杂想法整理成清晰故事。",
            identity: "品牌策略 · 深圳",
            followerCount: "3,628",
            projectCount: "36",
            imageName: "Pcard3"
        ),
    ]
}

struct SocialView: View {
    @State private var selectedProfile: ProfileCardModel?

    private let cards = ProfileCardMockData.cards

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeTop = proxy.safeAreaInsets.top
                let safeBottom = proxy.safeAreaInsets.bottom
                let availableWidth = proxy.size.width
                let availableHeight = proxy.size.height
                let baseCardWidth = min(max(availableWidth - 96, 260), 296)
                let cardWidth = baseCardWidth * 0.9
                let cardHeight = cardWidth * (493.0 / 296.0)
                let heroTop = safeTop + 28
                let stackTop = min(heroTop + 190, max(heroTop + 158, availableHeight - safeBottom - cardHeight - 118))

                ZStack(alignment: .topLeading) {
                    Color(hex: "F5F7F8")
                        .ignoresSafeArea()

                    heroHeader
                        .padding(.leading, 16)
                        .padding(.top, heroTop)

                    infoButton
                        .padding(.top, safeTop + 18)
                        .padding(.trailing, 16)
                        .frame(maxWidth: .infinity, alignment: .topTrailing)

                    ProfileCardStack(
                        cards: cards,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        onSelect: { card in
                            selectedProfile = card
                        }
                    )
                    .frame(width: availableWidth, height: cardHeight + 92)
                    .padding(.top, 320)

                    swipeHint
                        .frame(maxWidth: .infinity)
                        .padding(.top, stackTop + cardHeight + 72)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedProfile) { profile in
                SocialProfileDetailPlaceholder(profile: profile)
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOLINK")
                .font(.custom("Baloo-Regular", size: 24))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "FFD636"))
                .accessibilityAddTraits(.isHeader)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(hex: "FFD636"))
                    .frame(width: 207, height: 51)
                    .offset(x: 95, y: 46)
                    .accessibilityHidden(true)

                Text("不止一面\n才是真实的你。")
                    .font(.system(size: 46, weight: .bold))
                    .lineSpacing(-2)
                    .foregroundColor(Color(hex: "232253"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(height: 98, alignment: .topLeading)

            Text("展示真实的双面人格")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.7)
                .foregroundColor(Color(hex: "757D8C").opacity(0.72))
                .padding(.top, 2)
        }
    }

    private var swipeHint: some View {
        Text("↑  上滑 · 认识下一个人")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color(hex: "757D8C"))
            .multilineTextAlignment(.center)
            .accessibilityLabel("上滑，认识下一个人")
    }

    private var infoButton: some View {
        Button {
            // TODO: 接入社交页说明或筛选信息面板。
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color(hex: "232253"))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.86), in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("信息")
        .accessibilityHint("查看社交页面信息")
    }
}

struct ProfileCardStack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let cards: [ProfileCardModel]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onSelect: (ProfileCardModel) -> Void

    @State private var activeIndex = 0
    @GestureState private var dragTranslation: CGFloat = 0

    private let switchThreshold: CGFloat = 92

    var body: some View {
        ZStack {
            ForEach(cards.indices.reversed(), id: \.self) { index in
                if shouldRender(index) {
                    let layout = layout(for: index)

                    ProfileCardView(profile: cards[index])
                        .frame(width: cardWidth, height: cardHeight)
                        .scaleEffect(layout.scale)
                        .rotationEffect(.degrees(layout.rotation))
                        .offset(x: layout.x, y: layout.y)
                        .opacity(layout.opacity)
                        .zIndex(layout.zIndex)
                        .allowsHitTesting(index == activeIndex)
                        .accessibilityHidden(index != activeIndex)
                        .onTapGesture {
                            guard index == activeIndex else { return }
                            onSelect(cards[index])
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight + 80, alignment: .top)
        .contentShape(Rectangle())
        .gesture(cardDragGesture)
        .animation(stackAnimation, value: activeIndex)
        .animation(stackAnimation, value: dragTranslation)
        .sensoryFeedback(.selection, trigger: activeIndex)
    }

    private var stackAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(response: 0.48, dampingFraction: 0.82, blendDuration: 0.08)
    }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragTranslation) { value, state, _ in
                state = boundedDrag(value.translation.height)
            }
            .onEnded { value in
                let predicted = boundedDrag(value.predictedEndTranslation.height)
                let actual = boundedDrag(value.translation.height)
                let decision = abs(predicted) > abs(actual) ? predicted : actual

                if decision < -switchThreshold, activeIndex < cards.count - 1 {
                    activeIndex += 1
                } else if decision > switchThreshold, activeIndex > 0 {
                    activeIndex -= 1
                }
            }
    }

    private func boundedDrag(_ value: CGFloat) -> CGFloat {
        if value < 0, activeIndex == cards.count - 1 {
            return value * 0.28
        }
        if value > 0, activeIndex == 0 {
            return value * 0.28
        }
        return value
    }

    private func shouldRender(_ index: Int) -> Bool {
        let relative = index - activeIndex
        if relative >= 0, relative <= 2 { return true }
        if dragTranslation > 0, index == activeIndex - 1 { return true }
        return false
    }

    private func layout(for index: Int) -> CardLayout {
        let relative = index - activeIndex
        let upwardProgress = min(max(-dragTranslation / switchThreshold, 0), 1)
        let downwardProgress = min(max(dragTranslation / switchThreshold, 0), 1)

        if relative == 0 {
            let exitFade = dragTranslation < 0 ? Double(1 - upwardProgress * 0.22) : 1
            return CardLayout(
                x: 0,
                y: dragTranslation,
                scale: reduceMotion ? 1 : 1 - upwardProgress * 0.025,
                rotation: 0,
                opacity: exitFade,
                zIndex: 30
            )
        }

        if relative == 1 {
            return CardLayout(
                x: reduceMotion ? 0 : -32 + 32 * upwardProgress,
                y: -26 + 26 * upwardProgress,
                scale: reduceMotion ? 1 : 0.965 + 0.035 * upwardProgress,
                rotation: reduceMotion ? 0 : -5 + 5 * upwardProgress,
                opacity: 0.92 + 0.08 * Double(upwardProgress),
                zIndex: 20
            )
        }

        if relative == 2 {
            return CardLayout(
                x: reduceMotion ? 0 : -64 + 20 * upwardProgress,
                y: -50 + 14 * upwardProgress,
                scale: reduceMotion ? 1 : 0.93 + 0.025 * upwardProgress,
                rotation: reduceMotion ? 0 : -13 + 4 * upwardProgress,
                opacity: 0.68,
                zIndex: 10
            )
        }

        if relative == -1 {
            return CardLayout(
                x: reduceMotion ? 0 : -22 + 22 * downwardProgress,
                y: -cardHeight * 0.34 + cardHeight * 0.34 * downwardProgress,
                scale: reduceMotion ? 1 : 0.965 + 0.035 * downwardProgress,
                rotation: reduceMotion ? 0 : 4 - 4 * downwardProgress,
                opacity: Double(downwardProgress),
                zIndex: 25
            )
        }

        return CardLayout(x: 0, y: cardHeight, scale: 0.9, rotation: 0, opacity: 0, zIndex: 0)
    }
}

private struct CardLayout {
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let rotation: Double
    let opacity: Double
    let zIndex: Double
}

struct ProfileCardView: View {
    let profile: ProfileCardModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.white.opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(Color(hex: "EEEEEE"), lineWidth: 1)
                )
                .shadow(color: Color(hex: "15201E").opacity(0.04), radius: 35, x: 0, y: 16)

            imageLayer
                .padding(7)

            readabilityMask
                .padding(7)

            profileInfo
        }
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.name)，\(profile.identity)，\(profile.introduction)，\(profile.followerCount) 位关注者")
        .accessibilityAddTraits(.isButton)
    }

    private var imageLayer: some View {
        ZStack(alignment: .bottom) {
            Image(profile.imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "1F2527").opacity(0.0), location: 0.48),
                            .init(color: Color(hex: "606B6E").opacity(0.22), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                )

            LinearGradient(
                stops: [
                    .init(color: Color(hex: "F7FCFC").opacity(0.0), location: 0.1),
                    .init(color: Color(hex: "F4F4F4").opacity(0.78), location: 0.78),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 213)
            .blur(radius: 6)
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color(hex: "7C8B89").opacity(0.27), lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.4), lineWidth: 0.6)
                .blur(radius: 3)
        )
        .accessibilityHidden(true)
    }

    private var readabilityMask: some View {
        VStack {
            Spacer()

            ZStack(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.0), location: 0.0),
                        .init(color: Color(hex: "F7F8F5").opacity(0.72), location: 0.42),
                        .init(color: Color(hex: "F2F1EC").opacity(0.96), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.40))
                    .frame(height: 120)
                    .blur(radius: 18)
                    .offset(y: 20)
            }
            .frame(height: 210)
            .blendMode(.normal)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var profileInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(profile.name)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color(hex: "121212"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Color(hex: "0BA343"))
                        .accessibilityHidden(true)
                }

                Text(profile.introduction)
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(2)
                    .foregroundColor(Color(hex: "181818"))
                    .tracking(-0.3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(profile.identity)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "757D8C"))
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 16)

            HStack(spacing: 0) {
                HStack(spacing: 16) {
                    statItem(systemImage: "person", value: profile.followerCount)
                    statItem(systemImage: "square.stack.3d.up", value: profile.projectCount)
                }

                Spacer(minLength: 14)

                Button {
                    // TODO: 接入关注接口。
                } label: {
                    HStack(spacing: 6) {
                        Text("关注")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "181818"))
                    .frame(height: 44)
                    .padding(.horizontal, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color(hex: "EFEFEF"))
                            .shadow(color: Color(hex: "AAAEA8").opacity(0.86), radius: 16, x: 0, y: 0)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color(hex: "181818").opacity(0.03), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关注 \(profile.name)")
            }
            .padding(.leading, 24)
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
    }

    private func statItem(systemImage: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "181818").opacity(0.58))
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "181818"))
                .tracking(-0.14)
                .lineLimit(1)
        }
    }
}

private struct SocialProfileDetailPlaceholder: View {
    let profile: ProfileCardModel

    var body: some View {
        VStack(spacing: 16) {
            Image(profile.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())

            Text(profile.name)
                .font(.title2.weight(.bold))

            Text("个人详情页待接入")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
    }
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

#Preview("社交页") {
    SocialView()
}

#Preview("卡片堆叠") {
    ProfileCardStack(
        cards: ProfileCardMockData.cards,
        cardWidth: 296,
        cardHeight: 493,
        onSelect: { _ in }
    )
    .frame(width: 440, height: 640)
    .background(Color(hex: "F5F7F8"))
}
