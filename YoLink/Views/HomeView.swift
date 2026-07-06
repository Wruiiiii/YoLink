import SwiftUI

struct HomeView: View {

    @Binding var events: [EventItem]
    @State private var searchText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]


    private let demoCards: [DemoCard] = [
        DemoCard(title: "Google - AI Driven Research Workshop",
                 hostedBy: "Adnan K.",
                 location: "Skyline Lounge, Austin TX",
                 imageName: "CardBG1"),
        DemoCard(title: "Goldman - Investment In Digital Asset",
                 hostedBy: "Richard Galvin",
                 location: "200 West St, New York, NY",
                 imageName: "CardBG2"),
        DemoCard(title: "Masterpiece Society Art Appreciation",
                 hostedBy: "Michael Ma",
                 location: "Selwyn Ave K, Charlotte, NC",
                 imageName: "CardBG3"),
    ]


    var filteredEvents: [EventItem] {
        if searchText.isEmpty { return events }
        return events.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.location.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── "Group Events" title ─────────────────────
                    Text("Group Events")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .padding(.horizontal, 16)
                        .padding(.top, 30)
                        .padding(.bottom, 16)

                    // ── Search bar ───────────────────────────────
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    // ── Grid: demo cards + newly created events ──
                    // Demo cards always appear first.
                    // User-created events are appended at the end.
                    LazyVGrid(columns: columns, spacing: 12) {

                        // 1. Permanent demo cards
                        ForEach(demoCards) { card in
                            GridEventCardView(
                                title:      card.title,
                                hostedBy:   card.hostedBy,
                                location:   card.location,
                                imageName:  card.imageName,
                                coverImage: nil
                            )
                        }

                        // 2. User-created events appended after demo cards
                        ForEach(filteredEvents) { event in
                            GridEventCardView(
                                title:      event.name,
                                hostedBy:   event.hostedBy,
                                location:   event.location,
                                imageName:  nil,
                                coverImage: event.coverImage
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(hex: "FFF4DF").opacity(0.18))
            .navigationBarHidden(true)
        }
    }


    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "8E8E93"))

            TextField("Search events...", text: $searchText)
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "3A3A3A"))

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(hex: "F2F2F7"))
        .clipShape(Capsule())
    }
}


private struct DemoCard: Identifiable {
    let id       = UUID()
    let title:     String
    let hostedBy:  String
    let location:  String
    let imageName: String
}


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
    HomeView(events: .constant([
        EventItem(name: "My First Event",
                  location: "Austin, TX",
                  date: Date(),
                  hostedBy: "Jordan Miller"),
    ]))
}
