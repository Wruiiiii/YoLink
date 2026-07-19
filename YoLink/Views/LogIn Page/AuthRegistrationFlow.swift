import SwiftUI
import Combine

enum RegistrationStep: Hashable {
    case phoneVerification
    case createPassword
    case basicInformation
    case createProfile
}

enum RegistrationPasswordError: Equatable {
    case empty
    case tooShort
    case missingLetter
    case missingNumber
    case mismatch
    case mockMismatch
}

struct RegistrationMockData {
    static let countryCode = "+86"
    static let phoneNumber = "13888888888"
    static let verificationCode = "123456"
    static let canonicalPassword = "123yolink！"

    static func normalizePassword(_ password: String) -> String {
        password.replacingOccurrences(of: "!", with: "！")
    }

    static func maskedPhone(countryCode: String = Self.countryCode, phone: String) -> String {
        guard phone.count == 11 else { return "\(countryCode) \(phone)" }
        let prefix = phone.prefix(3)
        let suffix = phone.suffix(4)
        return "\(countryCode) \(prefix)****\(suffix)"
    }
}

protocol RegistrationAuthenticating {
    func validatePhone(_ phone: String) -> String?
    func validateVerificationCode(_ code: String) -> Bool
    func validatePassword(_ password: String, confirmation: String) -> RegistrationPasswordError?
}

struct AuthMockService: RegistrationAuthenticating {
    func validatePhone(_ phone: String) -> String? {
        guard phone.count == 11 else { return "请输入正确的 11 位手机号" }
        guard phone == RegistrationMockData.phoneNumber else { return "当前 Demo 请使用 13888888888" }
        return nil
    }

    func validateVerificationCode(_ code: String) -> Bool {
        code == RegistrationMockData.verificationCode
    }

    func validatePassword(_ password: String, confirmation: String) -> RegistrationPasswordError? {
        guard !password.isEmpty else { return .empty }
        guard password.count >= 8 else { return .tooShort }
        guard password.range(of: "[A-Za-z]", options: .regularExpression) != nil else { return .missingLetter }
        guard password.range(of: "[0-9]", options: .regularExpression) != nil else { return .missingNumber }
        guard password == confirmation else { return .mismatch }
        guard RegistrationMockData.normalizePassword(password) == RegistrationMockData.canonicalPassword else {
            return .mockMismatch
        }
        return nil
    }
}

@MainActor
final class RegistrationViewModel: ObservableObject {
    @Published private(set) var step: RegistrationStep = .phoneVerification
    @Published var phoneNumber = "" {
        didSet {
            let normalized = Self.digitsOnly(phoneNumber, limit: 11)
            if normalized != phoneNumber { phoneNumber = normalized }
            if oldValue != phoneNumber { phoneError = nil }
        }
    }
    @Published var verificationCode = "" {
        didSet {
            let normalized = Self.digitsOnly(verificationCode, limit: 6)
            if normalized != verificationCode { verificationCode = normalized }
            if oldValue != verificationCode { codeError = nil }
        }
    }
    @Published var password = "" {
        didSet { if oldValue != password { passwordError = nil } }
    }
    @Published var confirmPassword = "" {
        didSet { if oldValue != confirmPassword { passwordError = nil } }
    }
    @Published var phoneError: String?
    @Published var codeError: String?
    @Published var passwordError: String?
    @Published var resendSecondsRemaining = 0
    @Published private(set) var isCodeEntryActive = false
    @Published private(set) var isPhoneVerified = false
    @Published private(set) var areCredentialsCompleted = false

    let countryCode = RegistrationMockData.countryCode
    private let service: RegistrationAuthenticating
    private var resendTask: Task<Void, Never>?

    init(service: RegistrationAuthenticating? = nil) {
        self.service = service ?? AuthMockService()
    }

    deinit {
        resendTask?.cancel()
    }

    var isPhoneComplete: Bool {
        phoneNumber.count == 11
    }

    var isCodeComplete: Bool {
        verificationCode.count == 6
    }

    var hasMinimumPasswordFormat: Bool {
        password.count >= 8 &&
        password.range(of: "[A-Za-z]", options: .regularExpression) != nil &&
        password.range(of: "[0-9]", options: .regularExpression) != nil &&
        !confirmPassword.isEmpty
    }

    var maskedPhone: String {
        RegistrationMockData.maskedPhone(phone: phoneNumber)
    }

    var canResendCode: Bool {
        resendSecondsRemaining == 0
    }

    func submitPhone() {
        guard let error = service.validatePhone(phoneNumber) else {
            phoneError = nil
            verificationCode = ""
            codeError = nil
            isCodeEntryActive = true
            isPhoneVerified = false
            withAnimation(.easeInOut(duration: 0.24)) {
                step = .phoneVerification
            }
            startResendCountdown(seconds: 60)
            return
        }
        phoneError = error
    }

    func moveToCodeEntry() {
        guard service.validatePhone(phoneNumber) == nil else {
            submitPhone()
            return
        }
        withAnimation(.easeInOut(duration: 0.24)) {
            isCodeEntryActive = true
            isPhoneVerified = false
        }
        startResendCountdown(seconds: 60)
    }

    func submitCode() {
        guard isCodeComplete else { return }
        guard service.validatePhone(phoneNumber) == nil else {
            phoneError = "当前 Demo 请使用 13888888888"
            isCodeEntryActive = false
            step = .phoneVerification
            return
        }
        guard service.validateVerificationCode(verificationCode) else {
            codeError = "验证码错误，请重新输入"
            return
        }
        codeError = nil
        isPhoneVerified = true
        resendTask?.cancel()
        resendSecondsRemaining = 0
        withAnimation(.easeInOut(duration: 0.24)) {
            step = .createPassword
        }
    }

    func editPhone() {
        verificationCode = ""
        codeError = nil
        isCodeEntryActive = false
        isPhoneVerified = false
        resendTask?.cancel()
        resendSecondsRemaining = 0
    }

    func resendCode() {
        guard canResendCode else { return }
        codeError = nil
        verificationCode = ""
        startResendCountdown(seconds: 60)
    }

    func submitPassword() {
        guard isPhoneVerified else {
            step = .phoneVerification
            return
        }
        if let error = service.validatePassword(password, confirmation: confirmPassword) {
            passwordError = message(for: error)
            return
        }
        passwordError = nil
        password = ""
        confirmPassword = ""
        areCredentialsCompleted = true
        withAnimation(.easeInOut(duration: 0.24)) {
            step = .basicInformation
        }
    }

    func goBack() {
        switch step {
        case .phoneVerification:
            editPhone()
        case .createPassword:
            step = .phoneVerification
        case .basicInformation:
            step = .createPassword
            areCredentialsCompleted = false
        case .createProfile:
            step = .basicInformation
        }
    }

    func passwordRequirementState(_ requirement: PasswordRequirement) -> Bool {
        switch requirement {
        case .length:
            return password.count >= 8
        case .letterAndNumber:
            return password.range(of: "[A-Za-z]", options: .regularExpression) != nil &&
            password.range(of: "[0-9]", options: .regularExpression) != nil
        }
    }

    static func digitsOnly(_ value: String, limit: Int) -> String {
        String(value.filter(\.isNumber).prefix(limit))
    }

    private func startResendCountdown(seconds: Int) {
        resendTask?.cancel()
        resendSecondsRemaining = seconds
        resendTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    if self.resendSecondsRemaining > 0 {
                        self.resendSecondsRemaining -= 1
                    }
                    if self.resendSecondsRemaining == 0 {
                        self.resendTask?.cancel()
                        self.resendTask = nil
                    }
                }
            }
        }
    }

    private func message(for error: RegistrationPasswordError) -> String {
        switch error {
        case .empty:
            return "请输入密码"
        case .tooShort:
            return "密码至少需要 8 位字符"
        case .missingLetter:
            return "密码需要包含英文字母"
        case .missingNumber:
            return "密码需要包含数字"
        case .mismatch:
            return "两次输入的密码不一致"
        case .mockMismatch:
            return "当前 Demo 请使用密码 123yolink！"
        }
    }
}

enum PasswordRequirement: CaseIterable {
    case length
    case letterAndNumber

    var title: String {
        switch self {
        case .length: "至少 8 位字符"
        case .letterAndNumber: "包含字母和数字"
        }
    }
}

struct RegistrationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = RegistrationViewModel()

    var body: some View {
        ZStack {
            RegistrationTheme.background
                .ignoresSafeArea()

            Group {
                switch viewModel.step {
                case .phoneVerification:
                    if viewModel.isCodeEntryActive {
                        VerificationCodeView(viewModel: viewModel, onBack: { viewModel.editPhone() })
                            .transition(stepTransition)
                    } else {
                        PhoneEntryView(viewModel: viewModel, onClose: { dismiss() })
                            .transition(stepTransition)
                    }
                case .createPassword:
                    CreatePasswordView(viewModel: viewModel, onBack: { viewModel.goBack() })
                        .transition(stepTransition)
                case .basicInformation:
                    RegistrationNextStepPlaceholder(viewModel: viewModel, onBack: { viewModel.goBack() })
                        .transition(stepTransition)
                case .createProfile:
                    EmptyView()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }
}

private struct PhoneEntryView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onClose: () -> Void
    @FocusState private var focusedField: Field?

    private enum Field {
        case phone
    }

    var body: some View {
        RegistrationPageContainer(
            topButton: .close,
            onTopButtonTap: onClose,
            trailingTitle: "创建账号",
            bottomButtonTitle: "获取验证码",
            bottomButtonEnabled: viewModel.isPhoneComplete,
            bottomButtonAction: submit
        ) {
            VStack(alignment: .leading, spacing: 24) {
                RegistrationTitleBlock(
                    title: "输入手机号",
                    subtitle: "我们会向你的手机发送验证码"
                )

                VStack(alignment: .leading, spacing: 12) {
                    RegistrationFieldLabel("手机号")
                    HStack(spacing: 6) {
                        CountryCodeField(countryCode: viewModel.countryCode)
                            .frame(width: 82, height: 56)

                        GlassInputContainer {
                            TextField("请输入手机号", text: $viewModel.phoneNumber)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                                .font(RegistrationTheme.bodyFont)
                                .foregroundColor(RegistrationTheme.text)
                                .focused($focusedField, equals: .phone)
                                .submitLabel(.continue)
                                .onSubmit(submit)
                                .accessibilityLabel("请输入手机号")
                        }
                        .frame(height: 56)
                    }

                    InlineValidationMessage(message: viewModel.phoneError)
                }

                HStack(spacing: 4) {
                    Text("已有账号？")
                    Button("去登录") {
                        onClose()
                    }
                    .foregroundColor(RegistrationTheme.yellow)
                    .buttonStyle(.plain)
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(RegistrationTheme.text)
                .accessibilityElement(children: .combine)
            }
            .onAppear {
                focusedField = .phone
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }

    private func submit() {
        focusedField = nil
        viewModel.submitPhone()
    }
}

private struct VerificationCodeView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onBack: () -> Void
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        RegistrationPageContainer(
            topButton: .back,
            onTopButtonTap: onBack,
            trailingTitle: nil,
            bottomButtonTitle: "验证并继续",
            bottomButtonEnabled: viewModel.isCodeComplete,
            bottomButtonAction: submit
        ) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("输入验证码")
                        .font(RegistrationTheme.titleFont)
                        .foregroundColor(RegistrationTheme.text)

                    HStack(alignment: .top) {
                        Text("验证码已发送至\n\(viewModel.maskedPhone)")
                            .font(RegistrationTheme.bodyFont)
                            .foregroundColor(RegistrationTheme.text)
                            .lineSpacing(2)

                        Spacer()

                        Button("修改手机号") {
                            viewModel.editPhone()
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(RegistrationTheme.yellow)
                        .buttonStyle(.plain)
                    }
                }

                VerificationCodeField(code: $viewModel.verificationCode, isFocused: $isCodeFocused)

                InlineValidationMessage(message: viewModel.codeError)

                HStack(spacing: 6) {
                    Text("没有收到验证码？")
                        .foregroundColor(RegistrationTheme.text)

                    Button(resendTitle) {
                        viewModel.resendCode()
                    }
                    .disabled(!viewModel.canResendCode)
                    .foregroundColor(viewModel.canResendCode ? RegistrationTheme.yellow : RegistrationTheme.text.opacity(0.45))
                    .buttonStyle(.plain)

                    Spacer()

                    if viewModel.resendSecondsRemaining > 0 {
                        Label("\(viewModel.resendSecondsRemaining) 秒", systemImage: "clock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(RegistrationTheme.text)
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.system(size: 16, weight: .bold))

                #if DEBUG
                Text("Demo 验证码：123456")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RegistrationTheme.text.opacity(0.42))
                    .accessibilityLabel("Demo 验证码，一二三四五六")
                #endif
            }
            .onAppear {
                isCodeFocused = true
            }
            .onChange(of: viewModel.verificationCode) { _, newValue in
                if newValue.count == 6 {
                    submit()
                }
            }
        }
        .onTapGesture {
            isCodeFocused = false
        }
    }

    private var resendTitle: String {
        viewModel.canResendCode ? "重新发送" : "重新发送（\(viewModel.resendSecondsRemaining) 秒）"
    }

    private func submit() {
        guard viewModel.isCodeComplete else { return }
        isCodeFocused = false
        viewModel.submitCode()
    }
}

private struct CreatePasswordView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onBack: () -> Void
    @FocusState private var focusedField: Field?
    @State private var isPasswordVisible = false
    @State private var isConfirmationVisible = false

    private enum Field {
        case password
        case confirmation
    }

    var body: some View {
        RegistrationPageContainer(
            topButton: .back,
            onTopButtonTap: onBack,
            trailingTitle: "创建账号",
            bottomButtonTitle: "继续",
            bottomButtonEnabled: viewModel.hasMinimumPasswordFormat,
            bottomButtonAction: submit
        ) {
            VStack(alignment: .leading, spacing: 24) {
                RegistrationTitleBlock(
                    title: "创建密码",
                    subtitle: "请设置一个用于登录 YoLink 的密码"
                )

                VStack(alignment: .leading, spacing: 12) {
                    PasswordInputField(
                        placeholder: "请输入密码",
                        text: $viewModel.password,
                        isVisible: $isPasswordVisible,
                        focusedField: $focusedField,
                        field: .password,
                        textContentType: .newPassword,
                        accessibilityLabel: "请输入密码"
                    )
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmation }

                    PasswordInputField(
                        placeholder: "请再次输入密码",
                        text: $viewModel.confirmPassword,
                        isVisible: $isConfirmationVisible,
                        focusedField: $focusedField,
                        field: .confirmation,
                        textContentType: .newPassword,
                        accessibilityLabel: "请再次输入密码"
                    )
                    .submitLabel(.done)
                    .onSubmit(submit)

                    InlineValidationMessage(message: viewModel.passwordError)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(PasswordRequirement.allCases, id: \.self) { requirement in
                        PasswordRequirementRow(
                            title: requirement.title,
                            isSatisfied: viewModel.passwordRequirementState(requirement)
                        )
                    }
                }

                #if DEBUG
                Text("Demo 密码：123yolink！")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RegistrationTheme.text.opacity(0.42))
                #endif
            }
            .onAppear {
                focusedField = .password
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }

    private func submit() {
        focusedField = nil
        viewModel.submitPassword()
    }
}

private struct RegistrationNextStepPlaceholder: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onBack: () -> Void
    @State private var isIconFloating = false

    var body: some View {
        ZStack {
            RegistrationTheme.yellow
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    RegistrationTopButton(kind: .back, action: onBack)
                    Spacer()
                }
                .padding(.top, 48)
                .padding(.horizontal, RegistrationLayout.horizontalPadding)

                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 188, height: 188)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 128, weight: .bold))
                        .foregroundStyle(RegistrationTheme.navy, .white)
                        .shadow(color: RegistrationTheme.navy.opacity(0.16), radius: 18, x: 0, y: 10)
                        .offset(y: isIconFloating ? -8 : 8)
                        .animation(
                            .easeInOut(duration: 1.45).repeatForever(autoreverses: true),
                            value: isIconFloating
                        )
                }
                .onAppear {
                    isIconFloating = true
                }

                VStack(spacing: 8) {
                    Text("手机号与密码设置完成")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("下一步：完善基本信息")
                        .font(RegistrationTheme.bodyFont)
                        .foregroundColor(.white.opacity(0.92))
                }
                .multilineTextAlignment(.center)
                .padding(.top, 48)

                Spacer()

                GlassPrimaryButton(
                    title: "继续",
                    isEnabled: true,
                    foreground: RegistrationTheme.navy,
                    background: .white
                ) {
                }
                .padding(.horizontal, RegistrationLayout.horizontalPadding)
                .padding(.bottom, 60)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("手机号与密码设置完成，下一步完善基本信息")
    }
}

private struct RegistrationPageContainer<Content: View>: View {
    let topButton: RegistrationTopButton.Kind
    let onTopButtonTap: () -> Void
    let trailingTitle: String?
    let bottomButtonTitle: String
    let bottomButtonEnabled: Bool
    let bottomButtonAction: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    RegistrationTopButton(kind: topButton, action: onTopButtonTap)
                    Spacer()
                    if let trailingTitle {
                        Text(trailingTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(RegistrationTheme.navy)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                .padding(.top, 48)

                content
                    .padding(.top, 30)

                Spacer(minLength: 160)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RegistrationLayout.horizontalPadding)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            GlassPrimaryButton(
                title: bottomButtonTitle,
                isEnabled: bottomButtonEnabled,
                action: bottomButtonAction
            )
            .padding(.horizontal, RegistrationLayout.horizontalPadding)
            .padding(.bottom, 26)
            .padding(.top, 12)
            .background(.white.opacity(0.92))
        }
    }
}

private struct RegistrationTitleBlock: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(RegistrationTheme.titleFont)
                .foregroundColor(RegistrationTheme.text)
                .lineSpacing(0)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(RegistrationTheme.bodyFont)
                .foregroundColor(RegistrationTheme.text)
                .lineSpacing(2)
        }
    }
}

private struct RegistrationFieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(RegistrationTheme.bodyFont)
            .foregroundColor(RegistrationTheme.text)
    }
}

private struct CountryCodeField: View {
    let countryCode: String

    var body: some View {
        HStack(spacing: 8) {
            Text("🇨🇳")
                .font(.system(size: 22))
                .accessibilityLabel("中国")
            Text(countryCode)
                .font(RegistrationTheme.bodyFont)
                .foregroundColor(RegistrationTheme.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RegistrationTheme.inputMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RegistrationInputBorder())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("国家区号 \(countryCode)")
    }
}

private struct GlassInputContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            content
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RegistrationTheme.inputMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RegistrationInputBorder())
    }
}

private struct RegistrationInputBorder: View {
    var color: Color = RegistrationTheme.border

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(color, lineWidth: 1)
    }
}

private struct VerificationCodeField: View {
    @Binding var code: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused(isFocused)
                .opacity(0.01)
                .accessibilityLabel("6 位验证码")
                .accessibilityValue(code.isEmpty ? "未输入" : "已输入 \(code.count) 位")

            HStack(spacing: 7) {
                ForEach(0..<6, id: \.self) { index in
                    let character = character(at: index)
                    Text(character)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(RegistrationTheme.text)
                        .frame(width: 49, height: 56)
                        .background(RegistrationTheme.inputMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RegistrationInputBorder(
                                color: index == min(code.count, 5) && isFocused.wrappedValue
                                ? RegistrationTheme.primaryGreen
                                : RegistrationTheme.border
                            )
                        )
                        .accessibilityHidden(true)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused.wrappedValue = true
        }
    }

    private func character(at index: Int) -> String {
        guard index < code.count else { return "" }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }
}

private struct PasswordInputField<Field: Hashable>: View {
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    var focusedField: FocusState<Field?>.Binding
    let field: Field
    let textContentType: UITextContentType
    let accessibilityLabel: String

    var body: some View {
        GlassInputContainer {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(RegistrationTheme.bodyFont)
            .foregroundColor(RegistrationTheme.text)
            .focused(focusedField, equals: field)
            .accessibilityLabel(accessibilityLabel)

            Button {
                isVisible.toggle()
                focusedField.wrappedValue = field
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(RegistrationTheme.text.opacity(0.55))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "隐藏密码" : "显示密码")
        }
        .frame(height: 56)
    }
}

private struct PasswordRequirementRow: View {
    let title: String
    let isSatisfied: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSatisfied ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSatisfied ? RegistrationTheme.primaryGreen : RegistrationTheme.text.opacity(0.35))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(RegistrationTheme.text.opacity(0.72))
        }
        .accessibilityLabel("\(title)，\(isSatisfied ? "已满足" : "未满足")")
    }
}

private struct InlineValidationMessage: View {
    let message: String?

    var body: some View {
        if let message {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)
                Text(message)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(Color(hex: "D1463F"))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("错误：\(message)")
        }
    }
}

private struct RegistrationTopButton: View {
    enum Kind {
        case close
        case back
    }

    let kind: Kind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: kind == .close ? "xmark" : "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(RegistrationTheme.navy)
                .frame(width: 40, height: 40)
                .background(RegistrationTheme.yellow, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind == .close ? "关闭" : "返回")
    }
}

private struct GlassPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    var foreground: Color = .white
    var background: Color = RegistrationTheme.navy
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isEnabled ? foreground : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(buttonMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isEnabled ? 0.70 : 0.18),
                                    .white.opacity(isEnabled ? 0.16 : 0.08),
                                    RegistrationTheme.navy.opacity(isEnabled ? 0.10 : 0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: isEnabled ? RegistrationTheme.navy.opacity(0.18) : .clear, radius: 18, x: 0, y: 12)
                .shadow(color: isEnabled ? .white.opacity(0.45) : .clear, radius: 10, x: -4, y: -5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isEnabled ? [] : .isStaticText)
    }

    private var buttonMaterial: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isEnabled ? background.opacity(0.82) : RegistrationTheme.disabledButton.opacity(0.72))
            )
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(isEnabled ? 0.34 : 0.10),
                        .white.opacity(0.02),
                        .black.opacity(isEnabled ? 0.08 : 0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Capsule()
                    .fill(.white.opacity(isEnabled ? 0.24 : 0.08))
                    .frame(height: 14)
                    .blur(radius: 10)
                    .offset(y: -14),
                alignment: .top
            )
    }
}

private enum RegistrationLayout {
    static let horizontalPadding: CGFloat = 23
}

private enum RegistrationTheme {
    static let navy = Color(hex: "232253")
    static let yellow = Color(hex: "FFD636")
    static let figmaYellow = Color(hex: "FCD310")
    static let text = Color(hex: "333333")
    static let border = Color(hex: "E7EAEB")
    static let background = Color.white
    static let primaryGreen = Color(hex: "007B5D")
    static let disabledButton = Color(hex: "9997B2")
    static let inputMaterial = AnyShapeStyle(.white)
    static let titleFont = Font.system(size: 28, weight: .bold)
    static let bodyFont = Font.system(size: 13, weight: .regular)
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

#Preview("手机号输入默认状态") {
    NavigationStack {
        PhoneEntryView(viewModel: RegistrationViewModel(), onClose: {})
    }
}

#Preview("手机号错误状态") {
    let viewModel = RegistrationViewModel.preview(phone: "13800000000", phoneError: "当前 Demo 请使用 13888888888")
    NavigationStack {
        PhoneEntryView(viewModel: viewModel, onClose: {})
    }
}

#Preview("验证码输入状态") {
    let viewModel = RegistrationViewModel.preview(phone: "13888888888", code: "123")
    NavigationStack {
        VerificationCodeView(viewModel: viewModel, onBack: {})
    }
}

#Preview("验证码错误状态") {
    let viewModel = RegistrationViewModel.preview(phone: "13888888888", code: "000000", codeError: "验证码错误，请重新输入")
    NavigationStack {
        VerificationCodeView(viewModel: viewModel, onBack: {})
    }
}

#Preview("创建密码默认状态") {
    let viewModel = RegistrationViewModel.preview(step: .createPassword, phoneVerified: true)
    NavigationStack {
        CreatePasswordView(viewModel: viewModel, onBack: {})
    }
}

#Preview("密码不一致状态") {
    let viewModel = RegistrationViewModel.preview(
        step: .createPassword,
        phoneVerified: true,
        password: "123yolink！",
        confirmation: "123yolink?",
        passwordError: "两次输入的密码不一致"
    )
    NavigationStack {
        CreatePasswordView(viewModel: viewModel, onBack: {})
    }
}

#Preview("密码规则错误状态") {
    let viewModel = RegistrationViewModel.preview(
        step: .createPassword,
        phoneVerified: true,
        password: "123",
        confirmation: "123",
        passwordError: "密码至少需要 8 位字符"
    )
    NavigationStack {
        CreatePasswordView(viewModel: viewModel, onBack: {})
    }
}

#Preview("下一步占位状态") {
    let viewModel = RegistrationViewModel.preview(step: .basicInformation, phoneVerified: true)
    RegistrationNextStepPlaceholder(viewModel: viewModel, onBack: {})
}

private extension RegistrationViewModel {
    static func preview(
        step: RegistrationStep = .phoneVerification,
        phone: String = "",
        code: String = "",
        phoneVerified: Bool = false,
        phoneError: String? = nil,
        codeError: String? = nil,
        password: String = "",
        confirmation: String = "",
        passwordError: String? = nil
    ) -> RegistrationViewModel {
        let viewModel = RegistrationViewModel()
        viewModel.phoneNumber = phone
        viewModel.verificationCode = code
        viewModel.phoneError = phoneError
        viewModel.codeError = codeError
        viewModel.password = password
        viewModel.confirmPassword = confirmation
        viewModel.passwordError = passwordError
        viewModel.isPhoneVerified = phoneVerified
        viewModel.step = step
        return viewModel
    }
}
