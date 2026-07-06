import SwiftUI
import AuthenticationServices


private enum DT {
    static let navy         = Color(hex: "1E1B4B")
    static let yellow       = Color(hex: "FECD70")
    static let fieldBg      = Color(hex: "F2F3F8")
    static let labelGray    = Color(hex: "8E8E93")
    static let subtitleGray = Color(hex: "6B7280")
    static let borderGray   = Color(hex: "E5E7EB")

    static let fieldHeight:   CGFloat = 56
    static let fieldRadius:   CGFloat = 14
    static let buttonHeight:  CGFloat = 56
    static let horizontalPad: CGFloat = 24
    static let cardRadius:    CGFloat = 32

    // Figma card dimensions
    static let cardWidth:  CGFloat = 445
    static let cardHeight: CGFloat = 740
}



struct LoginView: View {

    @Bindable var viewModel: AuthViewModel
    var onSignUpTapped: () -> Void = {}

    @State private var showPassword = false

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Full-screen LoginBG image ────────────────────────
            Image("LoginBG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // ── White card — fixed W445 × H742, rounded top ──────
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Title + subtitle
                    Text("Welcome back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(DT.navy)
                        .padding(.top,15)
                        .padding(.bottom, 8)

                    Text("Please enter your details to sign in.")
                        .font(.system(size: 15))
                        .foregroundColor(DT.subtitleGray)
                        .padding(.bottom, 32)

                    // ── Email field ──────────────────────────────
                    fieldLabel("EMAIL ADDRESS")
                    emailField
                        .padding(.bottom, 30)

                    // ── Password field ───────────────────────────
                    HStack {
                        fieldLabel("PASSWORD")
                        Spacer()
                        Button("Forgot?") {}
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DT.yellow)
                            .buttonStyle(.plain)
                    }
                    passwordField
                        .padding(.bottom, 30)

                    // ── Sign In button ───────────────────────────
                    signInButton
                        .padding(.bottom, 30)

                    // ── OR divider ───────────────────────────────
                    orDivider
                        .padding(.bottom, 30)

                    // ── Social buttons ───────────────────────────
                    HStack(spacing: 12) {
                        socialButton(
                            label: "Google Account",
                            icon: AnyView(
                                Image("GoogleIcon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                            ),
                            action: viewModel.performGoogleLogin
                        )
                        socialButton(
                            label: "Apple Account",
                            icon: AnyView(
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 23, weight: .medium))
                                    .foregroundColor(.black)
                            ),
                            action: {}
                        )
                    }
                    .padding(.bottom, 32)

                    // ── Create account link ──────────────────────
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 15))
                            .foregroundColor(DT.subtitleGray)
                        Button("Create account") {
                            onSignUpTapped()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DT.yellow)
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, DT.horizontalPad)
                .padding(.top, 36)
                .frame(width: DT.cardWidth, alignment: .leading)
                .frame(minHeight: DT.cardHeight, alignment: .top)
            }
            .frame(width: DT.cardWidth, height: DT.cardHeight)
            .background(Color.white)
            .clipShape(
                .rect(
                    topLeadingRadius:    DT.cardRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius:   DT.cardRadius
                )
            )
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8)
        }
        .ignoresSafeArea(edges: .bottom)
        .alert("Sign In Failed", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // ============================================================
    // MARK: - Sub-views
    // ============================================================

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DT.labelGray)
            .tracking(1.0)
            .padding(.bottom, 8)
    }

    private var emailField: some View {
        TextField("name@company.com", text: $viewModel.email)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 16))
            .padding(.horizontal, 18)
            .frame(height: DT.fieldHeight)
            .background(DT.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: DT.fieldRadius))
    }

    private var passwordField: some View {
        HStack {
            if showPassword {
                TextField("••••••••", text: $viewModel.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 16))
            } else {
                SecureField("••••••••", text: $viewModel.password)
                    .font(.system(size: 16))
            }
            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 16))
                    .foregroundColor(DT.labelGray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .frame(height: DT.fieldHeight)
        .background(DT.fieldBg)
        .clipShape(RoundedRectangle(cornerRadius: DT.fieldRadius))
    }

    private var signInButton: some View {
        Button {
            viewModel.performEmailLogin()
        } label: {
            HStack(spacing: 10) {
                Text("Sign In")
                    .font(.system(size: 17, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: DT.buttonHeight)
            .background(DT.navy)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(DT.borderGray)
                .frame(height: 1)
            Text("OR CONTINUE WITH")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DT.labelGray)
                .tracking(0.8)
                .fixedSize()
            Rectangle()
                .fill(DT.borderGray)
                .frame(height: 1)
        }
    }

    private func socialButton(
        label: String,
        icon: AnyView,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "1A1A1A"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DT.borderGray, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255, green: Double(g) / 255,
                  blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}


#Preview {
    LoginView(viewModel: AuthViewModel())
}
