
import SwiftUI

// MARK: - Design tokens (Figma node 30-111)

private enum SheetDesign {
    static let sheetWidth: CGFloat = 440
    static let sheetHeight: CGFloat = 476
    static let cornerRadiusTop: CGFloat = 34
    static let cornerRadiusBottom: CGFloat = 58
    static let shadowRadius: CGFloat = 40
    static let shadowY: CGFloat = 8
    static let shadowOpacity: Double = 0.12
    
    static let titleFontSize: CGFloat = 26
    static let titleTracking: CGFloat = -0.23
    static let subtitleFontSize: CGFloat = 16
    static let subtitleColor = Color(hex: "8E8E93")
    
    static let buttonHeight: CGFloat = 65
    static let buttonHorizontalPadding: CGFloat = 20
    static let buttonCornerRadius: CGFloat = 1000
    static let buttonFontSize: CGFloat = 18
    static let primaryIconSize: CGFloat = 18
    static let secondaryButtonFill = Color(hex: "EFF1FF")
}

struct CreateActionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// Callback when user chooses "Create group Event"
    var onCreateGroupEvent: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 10) {
            // Toolbar: native grabber is shown via .presentationDragIndicator
            // Title "New Connection" + close button
            toolbar
            
            // Main title and subtitle (Figma 24:94)
            titleSection
                .padding(.top, 24)
                .padding(.horizontal, 30)
            
            // Buttons (Figma 24:74, 24:96)
            VStack(spacing: 20) {
                createGroupEventButton
                requestMeetupButton
            }
            .padding(.horizontal, 42)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: SheetDesign.sheetWidth)
        .frame(height: SheetDesign.sheetHeight)
        .background(
            RoundedRectangle(cornerRadius: SheetDesign.cornerRadiusTop, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(SheetDesign.shadowOpacity), radius: SheetDesign.shadowRadius, x: 0, y: SheetDesign.shadowY)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - Toolbar (Figma: Sheet header "New Connection" + leading close)
    
    private var toolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(hex: "727272"))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            
            Spacer(minLength: 0)
            
            Text("New Connection")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .tracking(-0.45)
            
            Spacer(minLength: 0)
            
            // Balance the leading close button so title stays centered
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 0)
        .padding(.bottom, 6)
    }
    
    // MARK: - Title block (Figma 24:94)
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What would you like to create?")
                .font(.system(size: SheetDesign.titleFontSize, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .tracking(SheetDesign.titleTracking)
            
            Text("Start a new event or meetup in your current city")
                .font(.system(size: SheetDesign.subtitleFontSize, weight: .regular))
                .foregroundColor(SheetDesign.subtitleColor)
                .tracking(SheetDesign.titleTracking)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Button 1: Create group Event (Figma 24:74 – primary)
    
    private var createGroupEventButton: some View {
        Button {
            print("Navigate to Group Event form")
            onCreateGroupEvent?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: SheetDesign.primaryIconSize))
                    .foregroundColor(.white)
                
                Text("Create group Event")
                    .font(.system(size: SheetDesign.buttonFontSize, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, SheetDesign.buttonHorizontalPadding)
            .frame(height: SheetDesign.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(Color("Theme"))
                    .shadow(color: .black.opacity(SheetDesign.shadowOpacity), radius: SheetDesign.shadowRadius, x: 0, y: SheetDesign.shadowY)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Button 2: Request 1:1 Meetup (Figma 24:96 – secondary)
    
    private var requestMeetupButton: some View {
        Button {
            print("Navigate to 1:1 Meetup form")
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: SheetDesign.primaryIconSize))
                    .foregroundColor(Color("Theme"))
                
                Text("Request 1:1 Meetup")
                    .font(.system(size: SheetDesign.buttonFontSize, weight: .semibold))
                    .foregroundColor(Color("Theme"))
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color("Theme"))
            }
            .padding(.horizontal, SheetDesign.buttonHorizontalPadding)
            .frame(height: SheetDesign.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(SheetDesign.secondaryButtonFill)
                    .overlay(
                        Capsule()
                            .stroke(Color("Theme").opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(SheetDesign.shadowOpacity), radius: SheetDesign.shadowRadius, x: 0, y: SheetDesign.shadowY)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color hex helper

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
    CreateActionSheetView()
}
