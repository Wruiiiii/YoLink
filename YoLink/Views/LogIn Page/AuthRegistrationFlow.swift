import SwiftUI
import Combine
import UIKit

enum RegistrationStep: Hashable {
    case phoneVerification
    case createPassword
    case dualCardIntroduction
    case profileCreation
    case profilePreview
    case completed
}

enum RegistrationProfileSide: Hashable {
    case professional
    case lifestyle

    var title: String {
        switch self {
        case .professional: "职业信息"
        case .lifestyle: "生活信息"
        }
    }
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

struct ProfessionalProfileDraft: Equatable {
    var name = "林知夏"
    var heroImageName = "Pcard1"
    var currentIdentity = "产品设计师"
    var schoolOrCompany = ""
    var region = "上海"
    var bio = ""
    var selectedSkills: [String] = []
}

struct LifestyleProfileDraft: Equatable {
    var statement = ""
    var selectedInterests: [String] = []
    var imageNames: [String] = ["LifePic", "Profile_R2"]
}

struct RegistrationProfileDraft: Equatable {
    var professional = ProfessionalProfileDraft()
    var lifestyle = LifestyleProfileDraft()
}

enum RegistrationProfileValidator {
    static func professionalError(for draft: ProfessionalProfileDraft) -> String? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请输入姓名" }
        if draft.currentIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           draft.schoolOrCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写你的职业身份"
        }
        if draft.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请添加一段职业简介" }
        return nil
    }

    static func lifestyleError(for draft: LifestyleProfileDraft) -> String? {
        if draft.selectedInterests.isEmpty { return "请至少选择一个兴趣" }
        if draft.imageNames.isEmpty { return "请添加一张生活照片" }
        if draft.statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请写一句关于生活中的你" }
        return nil
    }
}

struct MockProfileService {
    private(set) var lastSavedDraft: RegistrationProfileDraft?

    mutating func save(_ draft: RegistrationProfileDraft) {
        lastSavedDraft = draft
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
    @Published var profileDraft = RegistrationProfileDraft()
    @Published var editingProfileSide: RegistrationProfileSide = .professional
    @Published var profileCreationError: String?
    @Published private(set) var isRegistrationCompleted = false
    @Published private(set) var isCodeEntryActive = false
    @Published private(set) var isPhoneVerified = false
    @Published private(set) var areCredentialsCompleted = false

    let countryCode = RegistrationMockData.countryCode
    private let service: RegistrationAuthenticating
    private var profileService = MockProfileService()
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

    var canPreviewProfile: Bool {
        RegistrationProfileValidator.professionalError(for: profileDraft.professional) == nil &&
        RegistrationProfileValidator.lifestyleError(for: profileDraft.lifestyle) == nil
    }

    var previewProfileCard: ProfileCardModel {
        ProfileCardModel(
            name: profileDraft.professional.name.isEmpty ? "我的名片" : profileDraft.professional.name,
            introduction: profileDraft.professional.bio.isEmpty ? "正在创建我的 YoLink 双面卡片。" : profileDraft.professional.bio,
            identity: [profileDraft.professional.currentIdentity, profileDraft.professional.region]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " · "),
            followerCount: "0",
            projectCount: "\(max(profileDraft.professional.selectedSkills.count, 1))",
            imageName: profileDraft.professional.heroImageName
        )
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
            step = .dualCardIntroduction
        }
    }

    func startDualProfileCreation() {
        guard areCredentialsCompleted else {
            step = .createPassword
            return
        }
        profileCreationError = nil
        withAnimation(.easeInOut(duration: 0.24)) {
            step = .profileCreation
        }
    }

    func switchProfileSide(to side: RegistrationProfileSide) {
        profileCreationError = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            editingProfileSide = side
        }
    }

    func toggleSkill(_ skill: String) {
        if profileDraft.professional.selectedSkills.contains(skill) {
            profileDraft.professional.selectedSkills.removeAll { $0 == skill }
        } else {
            profileDraft.professional.selectedSkills.append(skill)
        }
        profileCreationError = nil
    }

    func toggleInterest(_ interest: String) {
        if profileDraft.lifestyle.selectedInterests.contains(interest) {
            profileDraft.lifestyle.selectedInterests.removeAll { $0 == interest }
        } else {
            profileDraft.lifestyle.selectedInterests.append(interest)
        }
        profileCreationError = nil
    }

    func previewProfile() {
        if let error = RegistrationProfileValidator.professionalError(for: profileDraft.professional) {
            editingProfileSide = .professional
            profileCreationError = error
            return
        }
        if let error = RegistrationProfileValidator.lifestyleError(for: profileDraft.lifestyle) {
            editingProfileSide = .lifestyle
            profileCreationError = error
            return
        }
        profileCreationError = nil
        withAnimation(.easeInOut(duration: 0.24)) {
            step = .profilePreview
        }
    }

    func completeRegistration() {
        guard areCredentialsCompleted, canPreviewProfile else {
            previewProfile()
            return
        }
        profileService.save(profileDraft)
        password = ""
        confirmPassword = ""
        isRegistrationCompleted = true
        withAnimation(.easeInOut(duration: 0.24)) {
            step = .completed
        }
    }

    func goBack() {
        switch step {
        case .phoneVerification:
            editPhone()
        case .createPassword:
            step = .phoneVerification
        case .dualCardIntroduction:
            step = .createPassword
            areCredentialsCompleted = false
        case .profileCreation:
            step = .dualCardIntroduction
        case .profilePreview:
            step = .profileCreation
        case .completed:
            break
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
    var onRegistrationCompleted: () -> Void = {}

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
                case .dualCardIntroduction:
                    DualProfileIntroductionView(viewModel: viewModel, onBack: { viewModel.goBack() })
                        .transition(stepTransition)
                case .profileCreation:
                    ProfileCreationView(viewModel: viewModel, onBack: { viewModel.goBack() })
                        .transition(stepTransition)
                case .profilePreview:
                    ProfilePreviewView(
                        viewModel: viewModel,
                        onBack: { viewModel.goBack() },
                        onCompleted: {
                            viewModel.completeRegistration()
                            if viewModel.isRegistrationCompleted {
                                onRegistrationCompleted()
                            }
                        }
                    )
                    .transition(stepTransition)
                case .completed:
                    Color.clear
                        .onAppear(perform: onRegistrationCompleted)
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
            trailingTitle: nil,
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
            trailingTitle: nil,
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

private struct DualProfileIntroductionView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onBack: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didRevealCards = false

    private let demoCard = ProfileCardMockData.cards.first!

    var body: some View {
        ZStack {
            Color(hex: "F5F7F8")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    RegistrationTopButton(kind: .back, action: onBack)
                    Spacer()
                }
                .padding(.top, 48)
                .padding(.horizontal, 16)

                RegistrationEditorialHeadline()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                ZStack {
                    ProfileCardView(profile: demoCard)
                        .frame(width: 296, height: 493)
                        .scaleEffect(0.92)
                        .rotationEffect(.degrees(didRevealCards && !reduceMotion ? 4.5 : 1))
                        .offset(x: didRevealCards && !reduceMotion ? 88 : 52, y: didRevealCards && !reduceMotion ? -4 : 10)
                        .opacity(0.58)
                        .accessibilityHidden(true)

                    ProfileCardView(profile: demoCard)
                        .frame(width: 296, height: 493)
                        .scaleEffect(0.94)
                        .rotationEffect(.degrees(didRevealCards && !reduceMotion ? -5 : -1))
                        .offset(x: didRevealCards && !reduceMotion ? -84 : -46, y: didRevealCards && !reduceMotion ? 10 : 14)
                        .opacity(0.66)
                        .accessibilityHidden(true)

                    ProfileCardView(profile: demoCard)
                        .frame(width: 296, height: 493)
                        .rotationEffect(.degrees(0))
                        .accessibilityLabel("双面卡片示例，展示职业面与生活面")
                }
                .frame(height: 524)
                .padding(.top, -4)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                        didRevealCards = true
                    }
                }

                VStack(spacing: 6) {
                    Text("每个人，都不止一面")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(RegistrationTheme.navy)
                    Text("用职业面展示经历与能力，用生活面分享兴趣与真实生活")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "757D8C"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .padding(.top, -12)

                Spacer(minLength: 18)

                GlassPrimaryButton(
                    title: "创建我的双面卡片",
                    isEnabled: true,
                    foreground: RegistrationTheme.navy,
                    background: .white
                ) {
                    viewModel.startDualProfileCreation()
                }
                .padding(.horizontal, 56)
                .padding(.bottom, 52)
            }
        }
    }
}

private struct ProfileCreationView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onBack: () -> Void
    @FocusState private var focusedField: Field?

    fileprivate enum Field: Hashable {
        case name
        case schoolOrCompany
        case bio
        case statement
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F9FA")
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        RegistrationTopButton(kind: .back, action: onBack)
                        Spacer()
                    }
                    .padding(.top, 48)
                    .padding(.horizontal, 20)

                    RegistrationEditorialHeadline()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.top, 4)

                    RegistrationProgressView(currentIndex: 1)
                        .padding(.top, 24)

                    Text("完善档案详情")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "0E0B3E"))
                        .padding(.top, 26)

                    ProfileSideSwitcher(
                        selection: viewModel.editingProfileSide,
                        isCompact: viewModel.editingProfileSide == .lifestyle
                    ) { side in
                        focusedField = nil
                        viewModel.switchProfileSide(to: side)
                    }
                    .padding(.top, 22)

                    VStack(spacing: 28) {
                        if viewModel.editingProfileSide == .professional {
                            ProfessionalProfileEditor(viewModel: viewModel, focusedField: $focusedField)
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        } else {
                            LifestyleProfileEditor(viewModel: viewModel, focusedField: $focusedField)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 148)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                InlineValidationMessage(message: viewModel.profileCreationError)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GlassPrimaryButton(
                    title: "预览我的卡片  →",
                    isEnabled: true,
                    action: {
                        focusedField = nil
                        viewModel.previewProfile()
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(RegistrationTheme.navy.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}

private struct ProfessionalProfileEditor: View {
    @ObservedObject var viewModel: RegistrationViewModel
    var focusedField: FocusState<ProfileCreationView.Field?>.Binding

    private let skillOptions = ["产品设计", "全栈开发", "AI算法", "品牌营销", "数据分析", "+ 自定义"]

    var body: some View {
        VStack(spacing: 28) {
            ProfileGlassPanel {
                RegistrationFieldLabel("姓名")
                GlassInputContainer {
                    TextField("例如：林知夏", text: $viewModel.profileDraft.professional.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(RegistrationTheme.navy)
                        .focused(focusedField, equals: .name)
                }
                .frame(height: 52)
            }

            ProfileGlassPanel {
                RegistrationFieldLabel("就读学校 / 现任职")
                GlassInputContainer {
                    TextField("例如：清华大学 · 交互设计", text: $viewModel.profileDraft.professional.schoolOrCompany)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(RegistrationTheme.navy)
                        .focused(focusedField, equals: .schoolOrCompany)
                }
                .frame(height: 52)
            }

            ProfileGlassPanel {
                RegistrationFieldLabel("核心领域（多选）")
                FlowTagLayout(items: skillOptions) { skill in
                    SelectableTag(
                        title: skill,
                        isSelected: viewModel.profileDraft.professional.selectedSkills.contains(skill)
                    ) {
                        viewModel.toggleSkill(skill)
                    }
                }
            }

            ProfileGlassPanel {
                RegistrationFieldLabel("职业语录")
                TextEditor(text: $viewModel.profileDraft.professional.bio)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(RegistrationTheme.navy)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 92)
                    .overlay(alignment: .topLeading) {
                        if viewModel.profileDraft.professional.bio.isEmpty {
                            Text("用一句话定义你的专业精神...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "86868B").opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .focused(focusedField, equals: .bio)
            }
        }
        .accessibilityLabel("职业信息编辑")
    }
}

private struct LifestyleProfileEditor: View {
    @ObservedObject var viewModel: RegistrationViewModel
    var focusedField: FocusState<ProfileCreationView.Field?>.Binding

    private let interestOptions = ["摄影", "咖啡", "徒步", "独立音乐", "旅行", "阅读"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                RegistrationFieldLabel("生活态度")
                GlassInputContainer {
                    TextField("总在寻找下一家好喝的咖啡馆。", text: $viewModel.profileDraft.lifestyle.statement)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(RegistrationTheme.navy)
                        .focused(focusedField, equals: .statement)
                }
                .frame(height: 52)
            }
            .padding(.horizontal, 0)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    RegistrationFieldLabel("兴趣爱好")
                    Spacer()
                    Label("添加", systemImage: "plus.circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(RegistrationTheme.navy)
                }
                FlowTagLayout(items: interestOptions) { interest in
                    SelectableTag(
                        title: interest,
                        isSelected: viewModel.profileDraft.lifestyle.selectedInterests.contains(interest)
                    ) {
                        viewModel.toggleInterest(interest)
                    }
                }
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                RegistrationFieldLabel("生活瞬间")
                LifestylePhotoGrid(imageNames: viewModel.profileDraft.lifestyle.imageNames)
                Text("* 照片将以 Liquid Glass 风格卡片展示在你的主页。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "86868B"))
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("生活信息编辑")
    }
}

private struct ProfilePreviewView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onBack: () -> Void
    let onCompleted: () -> Void
    @State private var isShowingLifestyle = false

    var body: some View {
        ZStack {
            Color(hex: "F8F9FA")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    RegistrationTopButton(kind: .back, action: onBack)
                    Spacer()
                }
                .padding(.top, 48)
                .padding(.horizontal, 20)

                RegistrationEditorialHeadline()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 4)

                RegistrationProgressView(currentIndex: 2)
                    .padding(.top, 24)

                Text("预览我的卡片")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "0E0B3E"))
                    .padding(.top, 24)

                Text("这是别人看到你的样子，之后仍可以随时修改")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "757D8C"))
                    .padding(.top, 8)

                RegistrationFlippableProfileCard(
                    frontProfile: viewModel.previewProfileCard,
                    lifestyleDraft: viewModel.profileDraft.lifestyle,
                    isShowingLifestyle: $isShowingLifestyle
                )
                .frame(width: 296, height: 493)
                .padding(.top, 28)
                .accessibilityAction(named: "翻转卡片") {
                    isShowingLifestyle.toggle()
                }

                Text(isShowingLifestyle ? "生活面" : "职业面")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(RegistrationTheme.navy.opacity(0.65))
                    .padding(.top, 14)

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    GlassPrimaryButton(title: "完成并进入 YoLink", isEnabled: true) {
                        onCompleted()
                    }
                    Button("返回修改") {
                        onBack()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(RegistrationTheme.navy)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
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

private struct RegistrationEditorialHeadline: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOLINK")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(RegistrationTheme.yellow)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(RegistrationTheme.yellow)
                    .frame(width: 207, height: 51)
                    .offset(x: 95, y: 46)
                    .accessibilityHidden(true)

                Text("不止一面\n才是真实的你。")
                    .font(.system(size: 46, weight: .bold))
                    .lineSpacing(-2)
                    .foregroundColor(RegistrationTheme.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(height: 98, alignment: .topLeading)

            Text("SHOW BOTH SIDES OF YOU")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.7)
                .foregroundColor(Color(hex: "757D8C").opacity(0.62))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("不止一面，才是真实的你。Show both sides of you")
    }
}

private struct RegistrationProgressView: View {
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? RegistrationTheme.navy : Color(hex: "EDEEEF"))
                    .frame(width: 48, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("注册进度，第 \(currentIndex + 1) 步，共 3 步")
    }
}

private struct ProfileSideSwitcher: View {
    let selection: RegistrationProfileSide
    var isCompact = false
    let onSelect: (RegistrationProfileSide) -> Void

    var body: some View {
        HStack(spacing: 0) {
            sideButton(.professional)
            sideButton(.lifestyle)
        }
        .padding(isCompact ? 5 : 4)
        .frame(maxWidth: isCompact ? 280 : .infinity)
        .background(isCompact ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(hex: "F3F4F5")), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(isCompact ? 0.6 : 0.35), lineWidth: 1)
        )
        .shadow(color: RegistrationTheme.navy.opacity(isCompact ? 0.05 : 0.04), radius: isCompact ? 20 : 8, x: 0, y: isCompact ? 4 : 2)
        .accessibilityElement(children: .contain)
    }

    private func sideButton(_ side: RegistrationProfileSide) -> some View {
        Button {
            onSelect(side)
        } label: {
            Text(side.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(selection == side ? RegistrationTheme.navy : Color(hex: "86868B"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, isCompact ? 6 : 12)
                .padding(.horizontal, isCompact ? 12 : 0)
                .background(selection == side ? (isCompact && side == .lifestyle ? RegistrationTheme.yellow : Color.white) : .clear, in: Capsule())
                .shadow(color: selection == side ? .black.opacity(0.10) : .clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(side.title)
        .accessibilityAddTraits(selection == side ? .isSelected : [])
    }
}

private struct ProfileGlassPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.white.opacity(0.45))
                .blendMode(.softLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color(hex: "232253").opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 2)
    }
}

private struct FlowTagLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

private struct SelectableTag: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(RegistrationTheme.navy)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(isSelected ? Color(hex: "FFE17B") : .white.opacity(0.42), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? .white.opacity(0.4) : RegistrationTheme.navy.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: isSelected ? .black.opacity(0.06) : .clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(isSelected ? "已选择" : "未选择")")
    }
}

private struct LifestylePhotoGrid: View {
    let imageNames: [String]

    var body: some View {
        GeometryReader { proxy in
            let column = (proxy.size.width - 16) / 3
            let largeWidth = column * 2 + 8

            HStack(spacing: 8) {
                imageTile(imageNames.first ?? "LifePic")
                    .frame(width: largeWidth, height: 256)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "heart")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(RegistrationTheme.navy)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(8)
                    }

                VStack(spacing: 8) {
                    imageTile(imageNames.dropFirst().first ?? "Profile_R2")
                        .frame(width: column, height: 124)

                    addTile
                        .frame(width: column, height: 124)
                }
            }
        }
        .frame(height: 256)
    }

    private func imageTile(_ imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            )
            .clipped()
            .accessibilityLabel("生活照片")
    }

    private var addTile: some View {
        VStack(spacing: 6) {
            Image(systemName: "camera.badge.plus")
                .font(.system(size: 25, weight: .medium))
            Text("添加")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Color(hex: "86868B"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(hex: "86868B").opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .accessibilityLabel("添加生活照片，当前使用 Demo 图片")
    }
}

private struct RegistrationFlippableProfileCard: View {
    let frontProfile: ProfileCardModel
    let lifestyleDraft: LifestyleProfileDraft
    @Binding var isShowingLifestyle: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ProfileCardView(profile: frontProfile)
                .opacity(isShowingLifestyle ? 0 : 1)
                .rotation3DEffect(.degrees(isShowingLifestyle && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            LifestyleCardBack(draft: lifestyleDraft)
                .opacity(isShowingLifestyle ? 1 : 0)
                .rotation3DEffect(.degrees(isShowingLifestyle && !reduceMotion ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .easeInOut(duration: 0.58), value: isShowingLifestyle)
        .onTapGesture {
            isShowingLifestyle.toggle()
        }
        .accessibilityLabel(isShowingLifestyle ? "生活面预览卡片" : "职业面预览卡片")
        .accessibilityHint("轻点翻转卡片")
    }
}

private struct LifestyleCardBack: View {
    let draft: LifestyleProfileDraft

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(Color(hex: "EEEEEE"), lineWidth: 1)
                )
                .shadow(color: Color(hex: "15201E").opacity(0.05), radius: 35, x: 0, y: 16)

            Image(draft.imageNames.first ?? "LifePic")
                .resizable()
                .scaledToFill()
                .padding(7)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))

            LinearGradient(
                colors: [.clear, Color(hex: "FFF7D1").opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))

            VStack(alignment: .leading, spacing: 14) {
                Text("生活面")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(RegistrationTheme.navy)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(RegistrationTheme.yellow, in: Capsule())

                Text(draft.statement.isEmpty ? "保持好奇，认真生活。" : draft.statement)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(RegistrationTheme.navy)
                    .lineLimit(3)

                FlowTagLayout(items: draft.selectedInterests.isEmpty ? ["摄影", "咖啡"] : draft.selectedInterests) { interest in
                    Text(interest)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(RegistrationTheme.navy)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.62), in: Capsule())
                }
            }
            .padding(28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isEnabled ? foreground : .white.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(buttonMaterial)
                .clipShape(buttonShape)
                .overlay(
                    buttonShape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isEnabled ? 0.74 : 0.42),
                                    .white.opacity(isEnabled ? 0.22 : 0.18),
                                    RegistrationTheme.navy.opacity(isEnabled ? 0.22 : 0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(specularHighlight)
                .shadow(color: RegistrationTheme.navy.opacity(isEnabled ? 0.20 : 0.08), radius: isEnabled ? 18 : 10, x: 0, y: isEnabled ? 12 : 6)
                .shadow(color: .white.opacity(isEnabled ? 0.80 : 0.38), radius: 10, x: -4, y: -5)
        }
        .buttonStyle(LiquidGlassPressButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isEnabled ? [] : .isStaticText)
    }

    private var buttonShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    @ViewBuilder
    private var buttonMaterial: some View {
        if reduceTransparency {
            buttonShape
                .fill(isEnabled ? background.opacity(0.86) : RegistrationTheme.navy.opacity(0.42))
                .overlay(surfaceTint)
        } else if #available(iOS 26.0, *) {
            buttonShape
                .fill(.clear)
                .glassEffect(
                    .regular
                        .tint((isEnabled ? background : RegistrationTheme.navy).opacity(isEnabled ? 0.28 : 0.22))
                        .interactive(isEnabled),
                    in: buttonShape
                )
                .overlay(surfaceTint)
        } else {
            buttonShape
                .fill(.ultraThinMaterial)
                .overlay(surfaceTint)
        }
    }

    private var surfaceTint: some View {
        buttonShape
            .fill(isEnabled ? background.opacity(0.46) : RegistrationTheme.navy.opacity(0.36))
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(isEnabled ? 0.28 : 0.18),
                        .white.opacity(0.04),
                        RegistrationTheme.navy.opacity(isEnabled ? 0.18 : 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var specularHighlight: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(isEnabled ? 0.30 : 0.16))
                .frame(height: 13)
                .blur(radius: 7)
                .padding(.horizontal, 22)
                .offset(y: -6)
            Spacer()
        }
        .clipShape(buttonShape)
        .allowsHitTesting(false)
    }
}

private struct LiquidGlassPressButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && isEnabled ? 0.975 : 1)
            .brightness(configuration.isPressed && isEnabled ? 0.035 : 0)
            .saturation(isEnabled ? 1 : 0.88)
            .animation(
                .spring(response: 0.24, dampingFraction: 0.78),
                value: configuration.isPressed
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

#Preview("创建账号完整流程") {
    NavigationStack {
        RegistrationFlowView()
    }
    .environmentObject(AppSessionViewModel())
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

#Preview("双面卡片介绍页面") {
    let viewModel = RegistrationViewModel.preview(step: .dualCardIntroduction, phoneVerified: true, credentialsCompleted: true)
    DualProfileIntroductionView(viewModel: viewModel, onBack: {})
}

#Preview("创建主页 - 职业面") {
    let viewModel: RegistrationViewModel = {
        let viewModel = RegistrationViewModel.preview(step: .profileCreation, phoneVerified: true, credentialsCompleted: true)
        viewModel.profileDraft.professional.bio = "设计人与技术之间的连接。"
        return viewModel
    }()
    ProfileCreationView(viewModel: viewModel, onBack: {})
}

#Preview("创建主页 - 生活面") {
    let viewModel: RegistrationViewModel = {
        let viewModel = RegistrationViewModel.preview(step: .profileCreation, phoneVerified: true, credentialsCompleted: true)
        viewModel.editingProfileSide = .lifestyle
        viewModel.profileDraft.lifestyle.statement = "总在寻找下一家好喝的咖啡馆。"
        viewModel.profileDraft.lifestyle.selectedInterests = ["摄影", "咖啡"]
        return viewModel
    }()
    ProfileCreationView(viewModel: viewModel, onBack: {})
}

#Preview("职业面缺少必填项") {
    let viewModel: RegistrationViewModel = {
        let viewModel = RegistrationViewModel.preview(step: .profileCreation, phoneVerified: true, credentialsCompleted: true)
        viewModel.profileDraft.professional.name = ""
        viewModel.profileCreationError = "请输入姓名"
        return viewModel
    }()
    ProfileCreationView(viewModel: viewModel, onBack: {})
}

#Preview("生活面缺少必填项") {
    let viewModel: RegistrationViewModel = {
        let viewModel = RegistrationViewModel.preview(step: .profileCreation, phoneVerified: true, credentialsCompleted: true)
        viewModel.editingProfileSide = .lifestyle
        viewModel.profileDraft.lifestyle.selectedInterests = []
        viewModel.profileCreationError = "请至少选择一个兴趣"
        return viewModel
    }()
    ProfileCreationView(viewModel: viewModel, onBack: {})
}

#Preview("完整卡片预览职业面") {
    let viewModel: RegistrationViewModel = {
        let viewModel = RegistrationViewModel.preview(step: .profilePreview, phoneVerified: true, credentialsCompleted: true)
        viewModel.profileDraft.professional.bio = "设计人与技术之间的连接。"
        viewModel.profileDraft.professional.selectedSkills = ["产品设计"]
        viewModel.profileDraft.lifestyle.statement = "总在寻找下一家好喝的咖啡馆。"
        viewModel.profileDraft.lifestyle.selectedInterests = ["摄影", "咖啡"]
        return viewModel
    }()
    ProfilePreviewView(viewModel: viewModel, onBack: {}, onCompleted: {})
}

#Preview("完整卡片预览生活面") {
    RegistrationFlippableProfileCard(
        frontProfile: ProfileCardMockData.cards[0],
        lifestyleDraft: {
            var draft = LifestyleProfileDraft()
            draft.statement = "总在寻找下一家好喝的咖啡馆。"
            draft.selectedInterests = ["摄影", "咖啡", "徒步"]
            return draft
        }(),
        isShowingLifestyle: .constant(true)
    )
    .frame(width: 296, height: 493)
    .padding()
    .background(Color(hex: "F8F9FA"))
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
        passwordError: String? = nil,
        credentialsCompleted: Bool = false
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
        viewModel.areCredentialsCompleted = credentialsCompleted
        viewModel.step = step
        return viewModel
    }
}
