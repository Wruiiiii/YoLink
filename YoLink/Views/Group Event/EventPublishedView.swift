

import SwiftUI

struct EventPublishedView: View {
    let eventName: String
    let location: String
    let date: Date
    let coverImage: Image?

    var onViewEvent: () -> Void
    var onBackToHome: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {

                    // ── Checkmark icon ──
                    ZStack {
                        Circle()
                            .fill(Color(hex: "E8EAFF"))
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(hex: "FECD70"))
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                    // ── Title ──
                    Text("Event Published!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .padding(.bottom, 12)

                    // ── Subtitle ──
                    Text("Great job! Your professional networking\nevent is now live and ready for attendees to\njoin.")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 36)

                    // ── Preview card ──
                    VStack(alignment: .leading, spacing: 0) {
                        // Cover image
                        ZStack {
                            if let img = coverImage {
                                img
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Rectangle()
                                    .fill(Color(hex: "C8D0F0"))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 36))
                                            .foregroundColor(.white.opacity(0.7))
                                    )
                            }
                        }
                        .frame(height: 200)
                        .clipped()
                        .clipShape(
                            .rect(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 20
                            )
                        )

                        // Card content
                        VStack(alignment: .leading, spacing: 10) {
                            // "UPCOMING" badge
                            Text("UPCOMING")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "FECD70"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: "E8EAFF"))
                                .clipShape(Capsule())

                            // Event name
                            Text(eventName.isEmpty ? "Your Event" : eventName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            // Date row
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "8E8E93"))
                                Text(formattedDateTime)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "8E8E93"))
                            }

                            // Location row
                            HStack(spacing: 8) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "8E8E93"))
                                Text(location.isEmpty ? "Location TBD" : location)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "8E8E93"))
                                    .lineLimit(1)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 20,
                                bottomTrailingRadius: 20,
                                topTrailingRadius: 0
                            )
                        )
                    }
                    .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)

                    // ── View Event button ──
                    Button(action: onViewEvent) {
                        Text("View Event")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(hex: "FECD70"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // ── Share to Network button ──
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrowshape.turn.up.right")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Share to Network")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "FECD70"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(hex: "E8EAFF"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    // ── Back to Home ──
                    Button(action: onBackToHome) {
                        Text("Back to Home")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color(hex: "F5F6F8"))

            // ── X dismiss button ──
            Button(action: onBackToHome) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .padding(12)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
    }

    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d • h:mm a"
        return formatter.string(from: date)
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

#Preview {
    EventPublishedView(
        eventName: "London Tech & VC Connect",
        location: "The Shard, London SE1",
        date: Date(),
        coverImage: nil,
        onViewEvent: {},
        onBackToHome: {}
    )
}
