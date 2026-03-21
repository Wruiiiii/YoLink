//
//  HomeView.swift
//  YoLink
//
//  Main home screen from Figma (node 13:23).
//  Group Events title, search bar, scrollable event cards.
//

import SwiftUI

struct HomeView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let cardWidth: CGFloat = 383
                let horizontalPadding = max(0, (geometry.size.width - cardWidth) / 2)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title section (Figma: "Group Events", 34pt bold)
                        Text("Group Events")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .tracking(0.4)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        
                        // Search bar (Figma: rounded pill, magnifying glass, mic)
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 17))
                                .foregroundColor(Color(hex: "727272"))
                            TextField("Search events...", text: $searchText)
                                .font(.system(size: 17))
                                .foregroundColor(Color(hex: "727272"))
                            Image(systemName: "mic.fill")
                                .font(.system(size: 17))
                                .foregroundColor(Color(hex: "727272"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "787880").opacity(0.16), lineWidth: 1)
                        )
                        .padding(.horizontal, max(16, horizontalPadding))
                        .padding(.bottom, 24)
                        
                        // Event cards (383×348pt, centered)
                        VStack(spacing: 16) {
                            EventCardView(
                                title: "Downtown Hub",
                                subtitle: "Tech Founders & VC Mixer",
                                location: "Skyline Lounge, Austin TX",
                                onJoinTap: { print("Join Event tapped") }
                            )
                            
                            EventCardView(
                                title: "Design Meetup",
                                subtitle: "Creative Minds",
                                location: "WeWork Downtown, Austin TX",
                                onJoinTap: { print("Join Event tapped") }
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 100)
                    }
                    .frame(maxWidth: geometry.size.width)
                }
            }
            .background(Color(hex: "F5F6F8"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Notifications
                    } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                }
            }
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
    HomeView()
}
