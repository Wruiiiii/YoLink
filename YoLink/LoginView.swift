//
//  LoginView.swift
//  YoLink
//
//  SwiftUI login screen based on Figma design.
//  Features: Apple Sign-In, Google Sign-In, phone number input, and footer links.
//

import SwiftUI
import AuthenticationServices

// MARK: - Design Tokens (from Figma node 1:41)

private enum DesignTokens {
    /// Neutral grays from Figma
    static let neutral400 = Color(hex: "E0E0E0")
    static let neutral600 = Color(hex: "9E9E9E")
    static let neutral900 = Color(hex: "424242")
    static let gray2 = Color(hex: "AEAEB2")
    
    /// Spacing (Figma: space-16 = 16pt)
    static let space8: CGFloat = 8
    static let space16: CGFloat = 16
    static let space17: CGFloat = 17  // Gap between Apple and Google (519 - 502)
    static let cornerRadius: CGFloat = 16
    
    /// Button dimensions (Figma: Apple 340×65, Google 340×58)
    static let appleButtonHeight: CGFloat = 58
    static let googleButtonHeight: CGFloat = 58
    static let buttonWidth: CGFloat = 340
    /// Horizontal padding: Figma left=57 on 400pt; use 25 to center 340pt on 390pt screen
    static let horizontalPadding: CGFloat = 25
}

// MARK: - Color Extension

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - LoginView

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header: Logo + Title (Figma: logo 90×90 at top, YoLink below)
                headerSection
                    .padding(.top, 100)
                    .padding(.bottom, 46)
                
                // Social Login Buttons (Figma: Apple 340×65, Google 340×58, gap 17pt)
                VStack(spacing: DesignTokens.space17) {
                    AppleLoginButton(onCompletion: viewModel.handleAppleSignInCompletion)
                    GoogleLoginButton(onTap: viewModel.performGoogleLogin)
                }
                .frame(width: DesignTokens.buttonWidth, alignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DesignTokens.horizontalPadding)
                .padding(.bottom, DesignTokens.space16)
                
                // OR Divider
                OrDivider()
                    .padding(.vertical, DesignTokens.space16)
                
                // Phone Number Input (match button width)
                PhoneNumberInputView(
                phoneNumber: $viewModel.phoneNumber,
                onSubmit: viewModel.performPhoneLogin,
                isLoading: false
                )
                .padding(.horizontal, DesignTokens.horizontalPadding)
                .padding(.bottom, 10)
                
                Spacer(minLength: 10)
                
                // Footer: Terms of Service
                TermsOfServiceFooter(onTermsTapped: viewModel.onTermsOfServiceTapped)
                    .padding(.bottom, 24)
                
                // Footer: Sign-up
//                SignUpFooter(onSignUpTapped: viewModel.onSignUpTapped)
//                    .padding(.bottom, 60)
            }
        }
        .background(Color.white)
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            // App Logo (Figma: 90×90, image 9 at left=191 top=154)
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            
            // App Name (Figma: 46pt bold, YoLink)
            Text("YoLink")
                .font(.system(size: 46, weight: .bold))
                .foregroundColor(.black)
                .tracking(-0.08)
            
            Text("Connect with professionals and discover your new city together.")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.gray.opacity(0.9))
                .tracking(-0.08)
                .multilineTextAlignment(.center)
                .frame(width: DesignTokens.buttonWidth)

            
        }
    }
}

// MARK: - Apple Login Button

/// Custom Apple Sign-In button matching Google button size (340×58pt) and radius (16pt).
/// Uses invisible native SignInWithAppleButton overlay for auth flow.
private struct AppleLoginButton: View {
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    
    var body: some View {
        ZStack {
            HStack(spacing: DesignTokens.space16) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                
                Text("Continue with Apple")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.45)
            }
            .frame(width: DesignTokens.buttonWidth, height: DesignTokens.googleButtonHeight)
            .background(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                    .stroke(DesignTokens.neutral400, lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius))
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
            
            SignInWithAppleButton(onRequest: { _ in }, onCompletion: { onCompletion($0) })
                .signInWithAppleButtonStyle(.white)
                .frame(width: DesignTokens.buttonWidth, height: DesignTokens.googleButtonHeight)
                .opacity(0.02)
                .allowsHitTesting(true)
        }
    }
}

// MARK: - Google Login Button

/// Custom "Continue with Google" button. (Figma: 340×58pt, white bg, gray border)
private struct GoogleLoginButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.space16) {
                Image("GoogleIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                
                Text("Continue with Google")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignTokens.neutral900)
                    .tracking(-0.45)
            }
            .frame(width: DesignTokens.buttonWidth, height: DesignTokens.googleButtonHeight)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                    .stroke(DesignTokens.neutral400, lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius))
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OR Divider

/// Horizontal divider with "OR" text in the center (Figma: two lines + OR).
private struct OrDivider: View {
    var body: some View {
        HStack(spacing: 8) {
            // Left line
            Rectangle()
                .fill(DesignTokens.gray2)
                .frame(height: 0.5)
                .frame(maxWidth: 150)
            
            Text("OR")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignTokens.gray2)
                .tracking(-0.31)
                
            
            // Right line
            Rectangle()
                .fill(DesignTokens.gray2)
                .frame(height: 0.5)
                .frame(maxWidth: 138)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
    }
}

// MARK: - Phone Number Input View

/// Custom text field for phone number with gray background and Theme-colored arrow submit button.
private struct PhoneNumberInputView: View {
    @Binding var phoneNumber: String
    let onSubmit: () -> Void
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            TextField("Phone Number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .font(.system(size: 18))
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(DesignTokens.neutral400.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius))
            
            // Blue arrow submit button (uses Theme color)
            Button(action: onSubmit) {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 58, height: 58)
                .background(Color("Theme"))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }
}

// MARK: - Terms of Service Footer

/// "By continuing, you agree to our Terms of Service" with tappable link.
private struct TermsOfServiceFooter: View {
    let onTermsTapped: () -> Void
    
    var body: some View {
        HStack(spacing: DesignTokens.space8) {
            Text("By continuing, you agree to our ")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.neutral600)
            
            Button(action: onTermsTapped) {
                Text("Terms of Service")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color("Theme"))
            }
            .buttonStyle(.plain)
        }
        .lineLimit(1)
    }
}

// MARK: - Sign-Up Footer

///// "Didn't have an Account!? Sign-up" with tappable link.
//private struct SignUpFooter: View {
//    let onSignUpTapped: () -> Void
//    
//    var body: some View {
//        HStack(spacing: DesignTokens.space8) {
//            Text("Didn't have an Account!? ")
//                .font(.system(size: 12))
//                .foregroundColor(DesignTokens.neutral600)
//            
//            Button(action: onSignUpTapped) {
//                Text("Sign-up")
//                    .font(.system(size: 12, weight: .semibold))
//                    .foregroundColor(Color("Theme"))
//            }
//            .buttonStyle(.plain)
//        }
//        .lineLimit(1)
//    }
//}

// MARK: - Preview

#Preview {
    LoginView(viewModel: AuthViewModel())
}
