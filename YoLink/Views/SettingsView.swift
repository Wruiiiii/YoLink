import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject var session: AppSessionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirm = false
    @State private var isLoggingOut      = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Account section ─────────────────────────────
                settingsSection(title: "Account") {
                    settingsRow(
                        icon: "person.circle",
                        iconColor: Color(hex: "2C4397"),
                        label: "Edit Profile"
                    ) {
                        // TODO: navigate to edit profile screen
                    }

                    Divider().padding(.leading, 52)

                    settingsRow(
                        icon: "bell",
                        iconColor: Color(hex: "2C4397"),
                        label: "Notifications"
                    ) {
                        // TODO: notifications settings
                    }

                    Divider().padding(.leading, 52)

                    settingsRow(
                        icon: "lock",
                        iconColor: Color(hex: "2C4397"),
                        label: "Privacy"
                    ) {
                        // TODO: privacy settings
                    }
                }

                // ── Support section ──────────────────────────────
                settingsSection(title: "Support") {
                    settingsRow(
                        icon: "questionmark.circle",
                        iconColor: Color(hex: "8E8E93"),
                        label: "Help & FAQ"
                    ) {}

                    Divider().padding(.leading, 52)

                    settingsRow(
                        icon: "envelope",
                        iconColor: Color(hex: "8E8E93"),
                        label: "Contact Us"
                    ) {}

                    Divider().padding(.leading, 52)

                    settingsRow(
                        icon: "doc.text",
                        iconColor: Color(hex: "8E8E93"),
                        label: "Terms of Service"
                    ) {}
                }

                // ── Danger zone ──────────────────────────────────
                settingsSection(title: "") {
                    Button {
                        showLogoutConfirm = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.red)
                            }

                            Text("Log Out")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)

                            Spacer()

                            if isLoggingOut {
                                ProgressView()
                                    .tint(.red)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoggingOut)
                }

                // ── App version ──────────────────────────────────
                Text("YoLink v1.0.0")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color(hex: "F2F3F8"))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        // ── Logout confirmation alert ────────────────────────────
        .confirmationDialog(
            "Are you sure you want to log out?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
                Task { await handleLogout() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Logout

    private func handleLogout() async {
        isLoggingOut = true
        await session.logout()
        // session.isLoggedIn = false triggers ContentView
        // to switch back to AuthFlowView automatically
    }

    // MARK: - Reusable components

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .tracking(0.5)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    private func settingsRow(
        icon: String,
        iconColor: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(iconColor)
                }

                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "C7C7CC"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
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
    NavigationStack {
        SettingsView()
            .environmentObject(AppSessionViewModel())
    }
}
