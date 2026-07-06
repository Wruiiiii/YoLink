import SwiftUI
import Combine

struct SignUpView: View {

    @EnvironmentObject var session: AppSessionViewModel
    @StateObject private var vm    = SignUpViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var name              = ""
    @State private var email             = ""
    @State private var password          = ""
    @State private var confirmPassword   = ""
    @State private var showPassword      = false
    @State private var showConfirmPassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "E8EAFF"))
                            .frame(width: 72, height: 72)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 30))
                            .foregroundColor(Color("Theme"))
                    }
                    Text("Create Account")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                    Text("Join YoLink to start connecting")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
                .padding(.top, 40)
                .padding(.bottom, 36)

                // ── Form fields ─────────────────────────────────
                VStack(spacing: 14) {

                    // Field 1 — Full Name
                    fieldLabel("Full Name")
                    plainField(
                        placeholder: "e.g. Jordan Miller",
                        icon: "person",
                        text: $name
                    )

                    // Field 2 — Email
                    fieldLabel("Email Address")
                    plainField(
                        placeholder: "you@example.com",
                        icon: "envelope",
                        text: $email,
                        keyboardType: .emailAddress,
                        autocap: .never
                    )

                    // Field 3 — Password
                    fieldLabel("Password")
                    secureField(
                        placeholder: "Min. 8 characters",
                        icon: "lock",
                        text: $password,
                        isVisible: $showPassword
                    )

                    // Field 4 — Confirm Password
                    fieldLabel("Confirm Password")
                    secureField(
                        placeholder: "Re-enter your password",
                        icon: "lock.fill",
                        text: $confirmPassword,
                        isVisible: $showConfirmPassword
                    )
                }
                .padding(.horizontal, 30)

                // ── Validation hint ──────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    if !password.isEmpty && password.count < 8 {
                        hintRow(
                            icon: "xmark.circle.fill",
                            color: .red,
                            text: "Password must be at least 8 characters"
                        )
                    } else if password.count >= 8 {
                        hintRow(
                            icon: "checkmark.circle.fill",
                            color: .green,
                            text: "Password length looks good"
                        )
                    }

                    if !confirmPassword.isEmpty && confirmPassword != password {
                        hintRow(
                            icon: "xmark.circle.fill",
                            color: .red,
                            text: "Passwords don't match"
                        )
                    } else if !confirmPassword.isEmpty && confirmPassword == password {
                        hintRow(
                            icon: "checkmark.circle.fill",
                            color: .green,
                            text: "Passwords match"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.top, 10)
                .padding(.bottom, 6)

                // ── API error ────────────────────────────────────
                if let error = vm.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 8)
                }

                // ── Create Account button ────────────────────────
                Button {
                    Task { await handleSignUp() }
                } label: {
                    ZStack {
                        Capsule()
                            .fill(isFormValid ? Color("Theme") : Color(hex: "C7C7CC"))
                            .frame(height: 58)

                        if vm.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Create Account")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .disabled(vm.isLoading || !isFormValid)

                // ── Already have account ─────────────────────────
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "8E8E93"))
                    Button("Log In") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color("Theme"))
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 48)
            }
        }
        .background(Color.white)
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.isSuccess) { _, success in
            if success { session.isLoggedIn = true }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && email.contains("@")
        && password.count >= 8
        && password == confirmPassword
    }

    // MARK: - Sign Up Action

    private func handleSignUp() async {
        await vm.signUp(
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            password: password,
            displayName: name.trimmingCharacters(in: .whitespaces)
        )
    }

    // MARK: - Field helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(hex: "1A1A1A"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func plainField(
        placeholder: String,
        icon: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        autocap: TextInputAutocapitalization = .words
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(width: 22)

            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
                .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color(hex: "F5F6F8"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
        )
    }

    private func secureField(
        placeholder: String,
        icon: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(width: 22)

            if isVisible.wrappedValue {
                TextField(placeholder, text: text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 16))
            } else {
                SecureField(placeholder, text: text)
                    .font(.system(size: 16))
            }

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color(hex: "F5F6F8"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
        )
    }

    private func hintRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(color)
        }
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
        SignUpView()
            .environmentObject(AppSessionViewModel())
    }
}
