//
//  EventCardView.swift
//  YoLink
//
//  Reusable event card component from Figma (node 13:1074).
//  White card with image, title, location, and Join Event button.
//

import SwiftUI

struct EventCardView: View {
    let title: String
    let subtitle: String?
    let location: String
    let imageName: String?
    let onJoinTap: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
        location: String,
        imageName: String? = nil,
        onJoinTap: @escaping () -> Void = {}
    ) {
        self.title = title
        self.subtitle = subtitle
        self.location = location
        self.imageName = imageName
        self.onJoinTap = onJoinTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image section (Figma: card total 383×348pt)
            ZStack {
                if let name = imageName {
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image("CardBG1")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: 383, height: 197)
            .clipped()
            
            // Content section (348 - 197 = 151pt)
            VStack(alignment: .leading, spacing: 8) {
                // Event title (20pt bold)
                VStack(alignment: .leading, spacing: 2) {
                    if let sub = subtitle {
                        Text(sub + ":")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .tracking(-0.23)
                    }
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .tracking(-0.23)
                }
                
                // Location (15pt, gray) with map pin icon
                HStack(spacing: 8) {
                    Image(systemName: "mappin")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                    Text(location)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "727272"))
                        .tracking(-0.25)
                }
                
                // Join Event button (Figma: 106×36, pill, Theme color)
                HStack {
                    Spacer()
                    Button(action: onJoinTap) {
                        Text("Join Event")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .tracking(-0.23)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .background(Color("Theme"))
                    .clipShape(Capsule())
                    .frame(height: 36)
                }
            }
            .padding(24)
        }
        .frame(width: 383, height: 348)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.25), radius: 3, x: 2, y: 2)
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
    EventCardView(
        title: "Downtown Hub",
        subtitle: "Tech Founders & VC Mixer",
        location: "Skyline Lounge, Austin TX"
    )
    .padding()
}
