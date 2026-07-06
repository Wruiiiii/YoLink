
import SwiftUI

struct SplashView: View {

    /// Binding — set to false after 2s to transition to main app
    @Binding var isActive: Bool

    /// Logo + text entrance
    @State private var contentOpacity: Double = 0
    @State private var contentOffset:  Double = 16

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // ── Exact Figma background colour ────────────────
                Color(red: 1, green: 0.84, blue: 0.21)
                    .ignoresSafeArea()

                // ── Falling ice cubes (behind text) ─────────────
                ForEach(IceCubeConfig.all) { config in
                    FallingIceCube(config: config, screenHeight: geo.size.height)
                }

                VStack(alignment: .center, spacing: 2) {

                    Text("Yolink")
                        .font(.custom("Baloo", size: 72))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    //Text("Career Growth | Coffee Chats | Events | Meetups")
                    Text("Link Vibes")
                        .font(.custom("Baloo", size: 15))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                // Horizontal padding matches Figma (53pt each side)
                .padding(.horizontal, 53)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: -geo.size.height * 0.06) // slight upward bias matching Figma
                .opacity(contentOpacity)
                .offset(y: contentOffset)
            }
        }
        .onAppear {
            // 1. Fade + slide content in
            withAnimation(.easeOut(duration: 0.65)) {
                contentOpacity = 1
                contentOffset  = 0
            }

            // 2. Transition to main app after exactly 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeIn(duration: 0.35)) {
                    isActive = false
                }
            }
        }
    }
}

// ============================================================
// MARK: - Ice Cube Configuration
// 5 cubes with varied size, position, timing, and rotation.
// Values are fixed so the animation is consistent every launch.
// ============================================================

struct IceCubeConfig: Identifiable {
    let id:            Int
    let size:          CGFloat   // frame width/height
    let xFraction:     CGFloat   // 0..1 — horizontal position across screen
    let duration:      Double    // total fall time in seconds
    let delay:         Double    // seconds before falling starts
    let startRotation: Double    // initial angle in degrees
    let endRotation:   Double    // final angle in degrees
    let opacity:       Double    // peak opacity (semi-transparent = glassy)

    static let all: [IceCubeConfig] = [
        IceCubeConfig(id: 0, size: 98,  xFraction: 0.08, duration: 1.9, delay: 0.00, startRotation: -18, endRotation:  42, opacity: 0.75),
        IceCubeConfig(id: 1, size: 80,  xFraction: 0.32, duration: 2.2, delay: 0.20, startRotation:  22, endRotation: -35, opacity: 0.75),
        IceCubeConfig(id: 2, size: 84,  xFraction: 0.60, duration: 2.0, delay: 0.08, startRotation: -6, endRotation:  50, opacity: 0.70),
        IceCubeConfig(id: 3, size: 64,  xFraction: 0.80, duration: 2.4, delay: 0.30, startRotation:  28, endRotation: -22, opacity: 0.50),
        IceCubeConfig(id: 4, size: 62,  xFraction: 0.47, duration: 2.1, delay: 0.42, startRotation: -55, endRotation:  38, opacity: 0.60),
        IceCubeConfig(id: 5, size: 74,  xFraction: 0.70, duration: 2.4, delay: 0.50, startRotation:  28, endRotation: -22, opacity: 0.65),
        IceCubeConfig(id: 6, size: 62,  xFraction: 0.17, duration: 2.1, delay: 0.58, startRotation: -30, endRotation:  38, opacity: 0.70),
    ]
}

struct FallingIceCube: View {

    let config:       IceCubeConfig
    let screenHeight: CGFloat

    @State private var yOffset:  CGFloat = 0
    @State private var rotation: Double  = 0
    @State private var opacity:  Double  = 0

    private var startY: CGFloat { -(config.size + 60) }
    private var endY:   CGFloat { screenHeight + config.size + 60 }

    var body: some View {
        GeometryReader { geo in
            Image("IceCube")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: config.size, height: config.size)
                .opacity(opacity)
                .rotationEffect(.degrees(rotation))
                .offset(
                    x: (geo.size.width * config.xFraction) - config.size / 2
                       + sin(rotation * .pi / 180) * 8,  // organic horizontal wobble
                    y: yOffset
                )
        }
        .onAppear {
            yOffset  = startY
            rotation = config.startRotation

            DispatchQueue.main.asyncAfter(deadline: .now() + config.delay) {
                // Fall + tumble
                withAnimation(.easeIn(duration: config.duration)) {
                    yOffset  = endY
                    rotation = config.endRotation
                }
                // Fade in at the start
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = config.opacity
                }
                // Fade out near the bottom
                withAnimation(
                    .easeOut(duration: 0.5)
                    .delay(config.duration - 0.5)
                ) {
                    opacity = 0
                }
            }
        }
    }
}


#Preview {
    SplashView(isActive: .constant(true))
}
