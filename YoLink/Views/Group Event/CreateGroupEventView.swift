
import SwiftUI
import MapKit
import PhotosUI

struct CreateGroupEventView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var events: [EventItem]

    @State private var showPublishedSheet = false
    @State private var publishedEvent: EventItem? = nil

    @State private var eventName: String = ""
    @State private var eventDescription: String = ""
    /// Extra line(s) typed in the TextField below the main description editor
    @State private var eventDescriptionLine: String = ""
    @State private var selectedCategory: String = "Social"
    @State private var participantLimit: Double = 20
    @State private var participantLimitText: String = "20"
    
    // Location
    @State private var locationText: String = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    // Location search
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var selectedMapItem: IdentifiableMapItem? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedCoverImage: Image?
    
    // Date & time (single shared state + expanding sections)
    @State private var eventDate = Date()
    @State private var isDateSectionExpanded = false
    @State private var isTimeSectionExpanded = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Base layer: main scrollable form
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        // Event title
                        sectionLabel("Event Title").padding(.horizontal, 20)
                        pillTextField(
                            text: $eventName,
                            placeholder: "e.g. Mid-week Tech Mixer"
                        )
                        .frame(width: Constants.formFrameWidth, height: Constants.formFrameHeight)
                        .frame(maxWidth: .infinity)
                                                
                        // Category chips
                        sectionLabel("Category")
                            .padding(.top, 10)
                            .padding(.bottom,5)
                            .padding(.horizontal, 20)
                        
                        categoryChips
                            .frame(width: Constants.formFrameWidth)
                            .frame(maxWidth: .infinity)
                        
                        // Date & time with overlay pickers (same row)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 16) {
                                // Date
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionLabel("Date")
                                    dateButton
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Time
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionLabel("Time")
                                    timeButton
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(width: Constants.formFrameWidth)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 20)
                        
                        // Location with map
                        sectionLabel("Location")
                            .padding(.top, 20)
                            .padding(.bottom,5)
                            .padding(.horizontal, 20)
                        
//                        VStack(spacing: 12) {
//                            HStack(spacing: 8) {
//                                Image(systemName: "mappin.and.ellipse")
//                                    .foregroundColor(Color("Theme"))
//                                TextField("Search for a location", text: $locationText)
//                                    .font(.system(size: 15))
//                                Button("Search") {
//                                    // TODO: hook up search
//                                    print("Search location: \\(locationText)")
//                                }
//                                .font(.system(size: 13, weight: .semibold))
//                                .padding(.horizontal, 10)
//                                .padding(.vertical, 8)
//                                .background(Color("Theme").opacity(0.1))
//                                .foregroundColor(Color("Theme"))
//                                .clipShape(Capsule())
//                            }
//                            .padding(.horizontal, 14)
//                            .padding(.vertical, 12)
//                            .frame(width: Constants.formFrameWidth, height: Constants.formFrameHeight)
//                            .background(
//                                RoundedRectangle(cornerRadius: 24)
//                                    .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
//                                    .background(
//                                        RoundedRectangle(cornerRadius: 24)
//                                            .fill(Color(.systemBackground))
//                                    )
//                            )
//                            .frame(maxWidth: .infinity)
//
//                            Map(coordinateRegion: $region)
//                                .frame(width: Constants.formFrameWidth, height: 200)
//                                .clipShape(RoundedRectangle(cornerRadius: 28))
//                                .frame(maxWidth: .infinity)
//                        }
                        VStack(spacing: 12) {
                            // Search bar
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(Color("Theme"))
                                TextField("Search for a location", text: $locationText)
                                    .font(.system(size: 15))
                                    .onChange(of: locationText) { newValue in
                                        searchTask?.cancel()
                                        if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                                            searchResults = []
                                            isSearching = false
                                            return
                                        }
                                        isSearching = true
                                        searchTask = Task {
                                            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s debounce
                                            guard !Task.isCancelled else { return }
                                            await performLocationSearch(query: newValue)
                                        }
                                    }
                                if isSearching {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if !locationText.isEmpty {
                                    Button {
                                        locationText = ""
                                        searchResults = []
                                        selectedMapItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color(hex: "8E8E93"))
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(width: Constants.formFrameWidth, height: Constants.formFrameHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color(.systemBackground))
                                    )
                            )
                            .frame(maxWidth: .infinity)

                            // Search results dropdown
                            if !searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(searchResults, id: \.self) { item in
                                        Button {
                                            selectLocation(item)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .foregroundColor(Color("Theme"))
                                                    .font(.system(size: 20))
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.name ?? "Unknown")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(Color(hex: "1A1A1A"))
                                                    if let address = formattedAddress(from: item.placemark) {
                                                        Text(address)
                                                            .font(.system(size: 12))
                                                            .foregroundColor(Color(hex: "8E8E93"))
                                                            .lineLimit(1)
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)

                                        if item != searchResults.last {
                                            Divider()
                                                .padding(.leading, 48)
                                        }
                                    }
                                }
                                .frame(width: Constants.formFrameWidth)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
                                )
                                .frame(maxWidth: .infinity)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searchResults.count)
                            }

                            // Map
                            Map(coordinateRegion: $region, annotationItems: selectedMapItem.map { [$0] } ?? []) { item in
                                MapMarker(coordinate: item.mapItem.placemark.coordinate, tint: Color("Theme"))
                            }
                            .frame(width: Constants.formFrameWidth, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Description (second screenshot)
                        sectionLabel("Event Description")
                            .padding(.top, 20)
                            .padding(.bottom,5)
                            .padding(.horizontal, 20)

                        TextEditor(text: $eventDescription)
                            .padding(10)
                            .frame(width: Constants.formFrameWidth, height: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color(.systemBackground))
                                    )
                            )
                            .frame(maxWidth: .infinity)
                        
//                        TextField("Add more details or notes…", text: $eventDescriptionLine, axis: .vertical)
//                            .font(.system(size: 15))
//                            .lineLimit(2...4)
//                            .padding(.horizontal, 16)
//                            .padding(.vertical, 12)
//                            .frame(width: Constants.formFrameWidth)
//                            .frame(minHeight: Constants.formFrameHeight)
//                            .background(
//                                RoundedRectangle(cornerRadius: 24)
//                                    .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
//                                    .background(
//                                        RoundedRectangle(cornerRadius: 24)
//                                            .fill(Color(.systemBackground))
//                                    )
//                            )
//                            .frame(maxWidth: .infinity)
                        
                        // Participant limit slider
                        sectionLabel("Participant Limit")
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                        Text("Up to \(Int(participantLimit)) participants")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .padding(.horizontal, 20)
                        HStack(spacing: Constants.participantNumberSpacing) {
                            Slider(value: $participantLimit, in: 2...100, step: 1)
                                .tint(Color("Theme"))
                                .frame(width: Constants.formFrameWidth - Constants.participantNumberPadWidth - Constants.participantNumberSpacing)
                                .onChange(of: participantLimit) { newValue in
                                    participantLimitText = String(Int(newValue))
                                }
                            
                            TextField("", text: $participantLimitText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: Constants.participantNumberPadWidth, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                                )
                                .onChange(of: participantLimitText) { newValue in
                                    if let value = Int(newValue), value >= 2, value <= 100 {
                                        participantLimit = Double(value)
                                    }
                                }
                        }
                        .frame(width: Constants.formFrameWidth, height: Constants.formFrameHeight)
                        .frame(maxWidth: .infinity)
                        
                        
                        // Event cover image (last section)
                        sectionLabel("Event Cover")
                            .padding(.top, 20)
                            .padding(.bottom,5)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(.systemGray6))
                                
                                if let image = selectedCoverImage {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 28))
                                            .foregroundColor(Color("Theme"))
                                        Text("Add a cover image")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "8E8E93"))
                                    }
                                }
                            }
                            .frame(width: Constants.formFrameWidth, height: 190)
                            .clipped()
                            .frame(maxWidth: .infinity)
                            
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("Choose from Photos")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(width: Constants.formFrameWidth, height: Constants.formFrameHeight)
                                .background(
                                    Capsule()
                                        .fill(Color("Theme").opacity(0.12))
                                )
                                .foregroundColor(Color("Theme"))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .onChange(of: selectedPhotoItem) { newItem in
                            guard let newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedCoverImage = Image(uiImage: uiImage)
                                }
                            }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
            
            // Top layer: floating overlay for date/time pickers (sibling of ScrollView in ZStack)
            if isDateSectionExpanded || isTimeSectionExpanded {
                ZStack {
                    // Dimming background
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isDateSectionExpanded = false
                            isTimeSectionExpanded = false
                        }
                    
                    // Floating card
                    VStack(spacing: 16) {
                        if isDateSectionExpanded {
                            Text("Select Date")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                            
                            DatePicker(
                                "",
                                selection: $eventDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .tint(Color("Theme"))
                        } else if isTimeSectionExpanded {
                            Text("Select Time")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                            
                            DatePicker(
                                "",
                                selection: $eventDate,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .tint(Color("Theme"))
                        }
                        
                        Button {
                            isDateSectionExpanded = false
                            isTimeSectionExpanded = false
                        } label: {
                            Text("Done")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color("Theme"))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                    .shadow(radius: 20)
                    .padding(.horizontal, 24)
                }
                .zIndex(1)
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Create Group Event")
                        .font(.system(size: 22, weight: .bold))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        let newEvent = EventItem(
                            name: eventName,
                            location: locationText,
                            date: eventDate,
                            coverImage: selectedCoverImage
                        )
                        publishedEvent = newEvent
                        showPublishedSheet = true
                    } label: {
                        Text("Publish Event")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: Constants.formFrameWidth, height: Constants.formFrameHeight, alignment: .center)
                            .background(Color("Theme"))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDateSectionExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isTimeSectionExpanded)
        .sheet(isPresented: $showPublishedSheet) {
            if let event = publishedEvent {
                EventPublishedView(
                    eventName: event.name,
                    location: event.location,
                    date: event.date,
                    coverImage: event.coverImage,
                    onViewEvent: {
                        events.append(event)
                        showPublishedSheet = false
                        dismiss()
                    },
                    onBackToHome: {
                        events.append(event)
                        showPublishedSheet = false
                        dismiss()
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }
    
    // MARK: - Helpers
    // MARK: - Location Search
    private func performLocationSearch(query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            await MainActor.run {
                searchResults = Array(response.mapItems.prefix(5))
                isSearching = false
            }
        } catch {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        selectedMapItem = IdentifiableMapItem(mapItem: item)  // ← wrap here
        locationText = item.name ?? ""
        searchResults = []
        isSearching = false

        let coordinate = item.placemark.coordinate
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    private func formattedAddress(from placemark: CLPlacemark) -> String? {
        let parts = [
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
    private var categoryChips: some View {
        let categories = ["Social", "Workshop", "Tech", "Networking", "Outdoors", "Creative"]
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
            ForEach(categories, id: \.self) { category in
                let isSelected = selectedCategory == category
                Button {
                    selectedCategory = category
                } label: {
                    Text(category)
                        .font(.system(size: 14))
                        .padding(.horizontal, Constants.Space300)
                        .padding(.vertical, Constants.Space200)
                        .frame(maxWidth: .infinity)
                        .background(
                            (isSelected ? Color(hex:"FFCA66") : Color(.systemGray6))
                        )
                        .cornerRadius(65)
                        .foregroundColor(isSelected ? .white : Color(hex: "1A1A1A"))
                }
                .buttonStyle(.plain)
            }
        }
    }
        
        private func pillTextField(text: Binding<String>, placeholder: String) -> some View {
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(.systemBackground))
                        )
                )
        }
        
        private var dateButton: some View {
            Button {
                isDateSectionExpanded.toggle()
                if isDateSectionExpanded {
                    isTimeSectionExpanded = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(Color(hex: "FECD70"))
                    Text(formattedDate)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(Color(hex: "F2F2F7"))
                )
            }
            .buttonStyle(.plain)
        }
        
        private var timeButton: some View {
            Button {
                isTimeSectionExpanded.toggle()
                if isTimeSectionExpanded {
                    isDateSectionExpanded = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundColor(Color(hex: "FECD70"))
                    Text(formattedTime)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(Color(hex: "F2F2F7"))
                )
            }
            .buttonStyle(.plain)
        }
        
        private func sectionLabel(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1A1A1A"))
        }
        
        private var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: eventDate)
        }
        
        private var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: eventDate)
        }
    }
    
    // MARK: - Color helper
    
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
        CreateGroupEventView(events: .constant([]))
    }
    
    // MARK: - Layout constants
    
    struct Constants {
        static let Space200: CGFloat = 10
        static let Space300: CGFloat = 20
        static let borderBrand: Color = Color(red: 0.63, green: 0.6, blue: 1)
        static let formFrameWidth: CGFloat = 370
        static let formFrameHeight: CGFloat = 65
        static let participantNumberPadWidth: CGFloat = 56
        static let participantNumberSpacing: CGFloat = 12
    }

    struct IdentifiableMapItem: Identifiable {
        let id = UUID()
        let mapItem: MKMapItem
    }
