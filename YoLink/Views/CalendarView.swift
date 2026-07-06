import SwiftUI


enum CalendarEventStatus {
    case joined
    case invited
}

struct CalendarEvent: Identifiable {
    let id        = UUID()
    let title:      String
    let location:   String
    let time:       String
    let amPm:       String
    let status:     CalendarEventStatus
    let imageName:  String?
}



struct CalendarView: View {

    @State private var currentMonth = Date()
    @State private var selectedDate = Date()

    private let eventDays: Set<Int> = [6, 12, 14]

    private let scheduleEvents: [CalendarEvent] = [
        CalendarEvent(
            title:     "Tech Founders Breakfast",
            location:  "Innovation Lab, Level 4",
            time:      "09:00",
            amPm:      "AM",
            status:    .joined,
            imageName: "CardBG1"
        ),
        CalendarEvent(
            title:     "Product Design Review",
            location:  "The Green Room",
            time:      "12:30",
            amPm:      "PM",
            status:    .invited,
            imageName: "CardBG2"
        ),
        CalendarEvent(
            title:     "Startup Pitch Night",
            location:  "Capital Factory",
            time:      "06:00",
            amPm:      "PM",
            status:    .joined,
            imageName: "CardBG3"
        ),
    ]

    private let yellow        = Color(hex: "FECD70")
    private let lightBlue     = Color(hex: "607AFB")
    private let pageGray      = Color(hex: "F2F3F8")
    private let textPrimary   = Color(hex: "1A1A1A")
    private let textSecondary = Color(hex: "8E8E93")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {

                    // ── Page title row ───────────────────────────
                    HStack(alignment: .firstTextBaseline) {
                        Text("Your Event Calendar")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(textPrimary)
                            .padding(.top,30)
                            .padding(.bottom,8)
                        Spacer()
                        Button("Today") {
                            withAnimation(.spring(response: 0.4)) {
                                currentMonth = Date()
                                selectedDate = Date()
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex:"F0BF00"))
                    }
                    .padding(.horizontal, 23)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    // ── Calendar card ────────────────────────────
                    calendarCard
                        .padding(.horizontal, 23)
                        .padding(.bottom, 25)

                    // ── My Schedule section ──────────────────────
                    scheduleSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                }
            }
            .background(pageGray)
            .navigationBarHidden(true)
        }
    }

    // ============================================================
    // MARK: - Calendar Card
    // ============================================================

    private var calendarCard: some View {
        VStack(spacing: 0) {

            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textPrimary)
                    .tracking(1.5)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(["S","M","T","W","T","F","S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)

            // Date grid
            let days = generateDays()
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: 4
            ) {
                ForEach(days.indices, id: \.self) { i in
                    if let day = days[i] {
                        dayCell(day: day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func dayCell(day: Int) -> some View {
        let isToday    = isToday(day: day)
        let isSelected = isSelected(day: day)
        let hasEvent   = eventDays.contains(day)

        return VStack(spacing: 3) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(yellow)
                        .frame(width: 36, height: 36)
                } else if isSelected {
                    Circle()
                        .fill(yellow.opacity(0.2))
                        .frame(width: 36, height: 36)
                }
                Text("\(day)")
                    .font(.system(size: 15, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundColor(isToday ? .black : isSelected ? yellow : textPrimary)
            }
            .frame(width: 36, height: 36)

            Circle()
                .fill(hasEvent ? yellow : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(height: 48)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                selectedDate = dateFor(day: day)
            }
        }
    }

    // ============================================================
    // MARK: - Schedule Section
    // ============================================================

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 20) {

            HStack(alignment: .firstTextBaseline) {
                Text("My Schedule")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textPrimary)
                Spacer()
                Text(shortDateLabel)
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(scheduleEvents.enumerated()), id: \.element.id) { index, event in
                    timelineRow(event: event, isLast: index == scheduleEvents.count - 1)
                }
            }
        }
    }

    private func timelineRow(event: CalendarEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {

            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.time)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textPrimary)
                Text(event.amPm)
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary)
            }
            .frame(width: 52, alignment: .trailing)
            .padding(.top, 18)

            // Vertical line + dot
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color(hex: "E0E0E0"))
                    .frame(width: 1.5)
                    .frame(height: 18)

                Circle()
                    .fill(event.status == .joined ? lightBlue : yellow)
                    .frame(width: 10, height: 10)

                Rectangle()
                    .fill(Color(hex: "E0E0E0"))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
                    .opacity(isLast ? 0 : 1)
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)

            // Card
            eventCard(event)
                .padding(.top, 8)
                .padding(.bottom, isLast ? 0 : 16)
        }
    }

    private func eventCard(_ event: CalendarEvent) -> some View {
        let accentColor = event.status == .joined ? lightBlue : yellow
        let statusLabel = event.status == .joined ? "JOINED EVENT" : "INVITED"

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {

                Text(statusLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accentColor)
                    .tracking(0.8)

                Text(event.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(textPrimary)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                    Text(event.location)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .lineLimit(1)
                }

                if event.status == .invited {
                    HStack(spacing: 12) {
                        Button("Accept") {}
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(yellow)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)

                        Button("Decline") {}
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(hex: "F2F2F7"))
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)

            if let name = event.imageName {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            HStack {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 4)
                    .cornerRadius(2)
                Spacer()
            }
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // ============================================================
    // MARK: - Calendar Helpers
    // ============================================================

    private var calendar: Calendar { Calendar.current }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: currentMonth).uppercased()
    }

    private var shortDateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: selectedDate)
    }

    private func generateDays() -> [Int?] {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: components),
              let range    = calendar.range(of: .day, in: .month, for: currentMonth)
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstDay)
        let offset  = weekday - 1

        var days: [Int?] = Array(repeating: nil, count: offset)
        days += range.map { Optional($0) }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func isToday(day: Int) -> Bool {
        let todayC = calendar.dateComponents([.year, .month, .day], from: Date())
        let monthC = calendar.dateComponents([.year, .month], from: currentMonth)
        return todayC.year == monthC.year && todayC.month == monthC.month && todayC.day == day
    }

    private func isSelected(day: Int) -> Bool {
        let selC   = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let monthC = calendar.dateComponents([.year, .month], from: currentMonth)
        return selC.year == monthC.year && selC.month == monthC.month && selC.day == day
    }

    private func dateFor(day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        return calendar.date(from: components) ?? currentMonth
    }
}

// ============================================================
// MARK: - Color Helper
// ============================================================

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
    CalendarView()
}
