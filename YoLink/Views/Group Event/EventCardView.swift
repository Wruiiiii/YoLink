import SwiftUI


struct GridEventCardView: View {

    let title:      String
    let hostedBy:   String
    let location:   String
    let imageName:  String?     // asset catalog name e.g. "CardBG1"
    let coverImage: Image?      // user photo from PhotosPicker

    private let cardWidth:   CGFloat = 201
    private let cardHeight:  CGFloat = 340
    private let imageHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Cover image ──────────────────────────────────
            ZStack {
                if let cover = coverImage {
                    cover
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: imageHeight)
                        .clipped()
                } else if let name = imageName, !name.isEmpty {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: imageHeight)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(hex: "D0D5F5"))
                        .frame(width: cardWidth, height: imageHeight)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
            }
            .frame(width: cardWidth, height: imageHeight)

            // ── Text content ─────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {

                // Title — Figma: width 187, height 52
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .frame(width: 187, height: 52, alignment: .topLeading)
                    .lineLimit(3)

                // Host row
                if !hostedBy.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "3A3A3A"))
                        Text("Hosted by \(hostedBy)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "3A3A3A"))
                            .lineLimit(1)
                    }
                }

                // Location row
                HStack(spacing: 6) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "3A3A3A"))
                    Text(location.isEmpty ? "Location TBD" : location)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "3A3A3A"))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, (cardWidth - 187) / 2)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .cornerRadius(10)
//        .overlay(
//            RoundedRectangle(cornerRadius:10)
//                .stroke(Color(hex:"FFF1B7"),lineWidth:1)
//        )
        //.shadow(color: .black.opacity(0.25),radius: 1, x: 1, y: 1)
    }
}

// MARK: - Color helper

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

#Preview {
    HStack(spacing: 12) {
        GridEventCardView(
            title:      "Google - AI Driven Research Workshop",
            hostedBy:   "Adnan K.",
            location:   "Skyline Lounge, Austin TX",
            imageName:  "CardBG1",
            coverImage: nil
        )
        GridEventCardView(
            title:      "Goldman - Investment In Digital Asset",
            hostedBy:   "Richard Galvin",
            location:   "200 West St, New York, NY",
            imageName:  "CardBG2",
            coverImage: nil
        )
    }
    .padding()
    .background(Color.white)
}
