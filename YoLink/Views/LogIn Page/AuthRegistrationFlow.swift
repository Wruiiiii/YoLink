import SwiftUI
import Combine
import UIKit
import PhotosUI
import UniformTypeIdentifiers

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
    var birthday = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    var heroImageName = "Pcard1"
    var heroImageData: Data?
    var currentIdentity = "产品设计师"
    var schoolOrCompany = ""
    var region = "上海"
    var bio = ""
    var selectedSkills: [String] = []
}

struct LifestyleProfileDraft: Equatable {
    var statement = ""
    var selectedInterests: [String] = []
    var imageNames: [String] = []
    var imageData: [Data] = []
}

struct RegistrationProfileDraft: Equatable {
    var professional = ProfessionalProfileDraft()
    var lifestyle = LifestyleProfileDraft()
}

enum RegistrationProfileValidator {
    static func professionalError(for draft: ProfessionalProfileDraft) -> String? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请输入姓名" }
        if draft.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请输入地区" }
        if draft.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请填写职业简介" }
        if draft.schoolOrCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请输入学校" }
        if draft.selectedSkills.isEmpty { return "请至少选择一个专业领域" }
        if draft.heroImageData == nil { return "请上传一张职业照片" }
        return nil
    }

    static func lifestyleError(for draft: LifestyleProfileDraft) -> String? {
        if draft.selectedInterests.isEmpty { return "请至少选择一个兴趣" }
        if draft.imageNames.isEmpty && draft.imageData.isEmpty { return "请添加一张生活照片" }
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

struct PickedProfileImageData: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PickedProfileImageData(data: data)
        }
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
            imageName: profileDraft.professional.heroImageName,
            imageData: profileDraft.professional.heroImageData
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
            guard profileDraft.professional.selectedSkills.count < 5 else {
                profileCreationError = "最多选择 5 个专业领域"
                return
            }
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

    func addCustomSkill(_ skill: String) {
        let trimmed = skill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !profileDraft.professional.selectedSkills.contains(trimmed) {
            guard profileDraft.professional.selectedSkills.count < 5 else {
                profileCreationError = "最多选择 5 个专业领域"
                return
            }
            profileDraft.professional.selectedSkills.append(trimmed)
        }
        profileCreationError = nil
    }

    func updateProfessionalPhotoData(_ data: Data) {
        guard !data.isEmpty else { return }
        profileDraft.professional.heroImageData = data
        profileCreationError = nil
    }

    func removeProfessionalPhoto() {
        profileDraft.professional.heroImageData = nil
        profileCreationError = nil
    }

    func addCustomInterest(_ interest: String) {
        let trimmed = interest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !profileDraft.lifestyle.selectedInterests.contains(trimmed) {
            profileDraft.lifestyle.selectedInterests.append(trimmed)
        }
        profileCreationError = nil
    }

    func addLifestylePhotoData(_ data: Data) {
        guard !data.isEmpty else { return }
        profileDraft.lifestyle.imageData.append(data)
        profileCreationError = nil
    }

    func removeLifestylePhoto(at index: Int) {
        if index < profileDraft.lifestyle.imageData.count {
            profileDraft.lifestyle.imageData.remove(at: index)
        } else {
            let demoIndex = index - profileDraft.lifestyle.imageData.count
            if demoIndex >= 0, demoIndex < profileDraft.lifestyle.imageNames.count {
                profileDraft.lifestyle.imageNames.remove(at: demoIndex)
            }
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
    @State private var isDemoCardShowingBack = false

    private let demoCard = ProfileCardMockData.cards.first!
    private let demoBackCard = ProfileCardModel(
        name: "林知夏",
        introduction: "专业咖啡师，用一杯咖啡连接真实日常。",
        identity: "咖啡师 · 生活探索者",
        followerCount: "1,286",
        projectCount: "48",
        imageName: "LifePic"
    )
    private let trailingDemoCard = ProfileCardMockData.cards[2]
    private let leadingDemoCard = ProfileCardMockData.cards[1]

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
                    ProfileCardView(profile: trailingDemoCard)
                        .frame(width: 266, height: 463)
                        .scaleEffect(0.92)
                        .rotationEffect(.degrees(didRevealCards && !reduceMotion ? 4.5 : 1))
                        .offset(x: didRevealCards && !reduceMotion ? 88 : 52, y: didRevealCards && !reduceMotion ? -4 : 10)
                        .opacity(0.58)
                        .accessibilityHidden(true)

                    ProfileCardView(profile: leadingDemoCard)
                        .frame(width: 266, height: 463)
                        .scaleEffect(0.94)
                        .rotationEffect(.degrees(didRevealCards && !reduceMotion ? -5 : -1))
                        .offset(x: didRevealCards && !reduceMotion ? -84 : -46, y: didRevealCards && !reduceMotion ? 10 : 14)
                        .opacity(0.66)
                        .accessibilityHidden(true)

                    IntroFlippableProfileCard(
                        frontProfile: demoCard,
                        backProfile: demoBackCard,
                        isShowingBack: $isDemoCardShowingBack
                    )
                        .frame(width: 250, height: 450)
                        .rotationEffect(.degrees(0))
                        .accessibilityLabel("双面卡片示例，展示职业面与生活面")
                }
                .frame(height: 450)
                .padding(.top,0)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                        didRevealCards = true
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(1200))
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.62)) {
                                isDemoCardShowingBack = true
                            }
                        }
                    }
                }

                VStack(spacing: 6) {
                    Text("用职业面展示经历与能力，用生活面分享兴趣与真实生活")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "757D8C"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .padding(.top, 10)

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
                .padding(.bottom, 45)
            }
        }
    }
}

private struct IntroFlippableProfileCard: View {
    let frontProfile: ProfileCardModel
    let backProfile: ProfileCardModel
    @Binding var isShowingBack: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ProfileCardView(profile: frontProfile)
                .opacity(isShowingBack ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isShowingBack && !reduceMotion ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.74
                )

            ProfileCardView(profile: backProfile)
                .opacity(isShowingBack ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isShowingBack && !reduceMotion ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.74
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .onTapGesture {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.62)) {
                isShowingBack.toggle()
            }
        }
        .accessibilityHint("点击可翻转双面卡片")
    }
}

private struct ProfileCreationView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onBack: () -> Void
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    fileprivate enum Field: Hashable {
        case name
        case region
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

//                    RegistrationProgressView(currentIndex: 1)
//                        .padding(.top, 24)
//                        .padding(.bottom, 30)

                    VStack(spacing: 20) {
                        Text("完善档案详情")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color(hex: "0E0B3E"))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, viewModel.editingProfileSide == .professional ? 16 : 10)

                        ProfileSideSwitcher(
                            selection: viewModel.editingProfileSide,
                            isCompact: viewModel.editingProfileSide == .lifestyle
                        ) { side in
                            focusedField = nil
                            viewModel.switchProfileSide(to: side)
                        }
                        .frame(maxWidth: viewModel.editingProfileSide == .lifestyle ? 280 : .infinity)
                        .frame(maxWidth: .infinity, alignment: .center)

                        if viewModel.editingProfileSide == .professional {
                            ProfessionalProfileEditor(viewModel: viewModel, focusedField: $focusedField)
                                .transition(
                                    reduceMotion
                                    ? .opacity
                                    : .move(edge: .leading).combined(with: .opacity)
                                )
                        } else {
                            LifestyleProfileEditor(viewModel: viewModel, focusedField: $focusedField)
                                .transition(
                                    reduceMotion
                                    ? .opacity
                                    : .move(edge: .trailing).combined(with: .opacity)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 150)
                    .animation(.spring(response: 0.34, dampingFraction: 0.9), value: viewModel.editingProfileSide)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            RegistrationBottomActionBar(errorMessage: viewModel.profileCreationError) {
                focusedField = nil
                viewModel.previewProfile()
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
    @State private var customSkill = ""
    @State private var photoPickerItem: PhotosPickerItem?
    @FocusState private var isCustomSkillFocused: Bool

    private let skillOptions = ["产品设计", "软件开发", "人工智能", "数据分析", "市场营销", "生物医学工程"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileFieldSection(title: "基本信息") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        TextField("请输入姓名", text: $viewModel.profileDraft.professional.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "0E0B3E"))
                            .focused(focusedField, equals: .name)
                            .submitLabel(.next)

                        Image(systemName: "person")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "86868B").opacity(0.55))
                            .accessibilityHidden(true)
                    }
                    .profileGlassInputStyle()

                    DatePicker(
                        "生日",
                        selection: $viewModel.profileDraft.professional.birthday,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "0E0B3E"))
                    .tint(RegistrationTheme.navy)
                    .profileGlassInputStyle()
                    .accessibilityLabel("生日")

                    HStack(spacing: 10) {
                        TextField("请输入地区", text: $viewModel.profileDraft.professional.region)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "0E0B3E"))
                            .focused(focusedField, equals: .region)
                            .submitLabel(.next)

                        Image(systemName: "location")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "86868B").opacity(0.55))
                            .accessibilityHidden(true)
                    }
                    .profileGlassInputStyle()
                }
            }

            ProfileFieldSection(title: "职业简介") {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 10) {
                        TextField("用一句话介绍你的职业方向", text: $viewModel.profileDraft.professional.bio, axis: .vertical)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "0E0B3E"))
                            .lineLimit(1...3)
                            .focused(focusedField, equals: .bio)
                            .onChange(of: viewModel.profileDraft.professional.bio) { _, newValue in
                                if newValue.count > 80 {
                                    viewModel.profileDraft.professional.bio = String(newValue.prefix(80))
                                }
                            }

                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "86868B").opacity(0.55))
                        .accessibilityHidden(true)
                    }
                    .profileGlassInputStyle()

                    Text("\(viewModel.profileDraft.professional.bio.count)/80")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "86868B"))
                        .padding(.trailing, 8)
                        .accessibilityLabel("职业简介字数 \(viewModel.profileDraft.professional.bio.count) / 80")
                }
            }

            ProfileFieldSection(title: "学校") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        TextField("请输入你的学校", text: $viewModel.profileDraft.professional.schoolOrCompany)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "0E0B3E"))
                            .focused(focusedField, equals: .schoolOrCompany)
                            .submitLabel(.done)

                        Image(systemName: "graduationcap")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "86868B").opacity(0.55))
                        .accessibilityHidden(true)
                    }
                    .profileGlassInputStyle()

                    if !viewModel.profileDraft.professional.schoolOrCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ProfileTag(
                            title: viewModel.profileDraft.professional.schoolOrCompany,
                            isSelected: true,
                            showsRemoveIcon: true
                        ) {
                            viewModel.profileDraft.professional.schoolOrCompany = ""
                        }
                    }
                }
            }

            ProfileFieldSection(title: "专业领域") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Spacer()
                        TagAddButton(title: "添加") {
                            isCustomSkillFocused = true
                        }
                        .accessibilityLabel("添加专业领域")
                    }

                    FlowTagLayout(items: allSkillOptions) { skill in
                        ProfileTag(
                            title: skill,
                            isSelected: viewModel.profileDraft.professional.selectedSkills.contains(skill),
                            showsRemoveIcon: true
                        ) {
                            viewModel.toggleSkill(skill)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        TextField("添加领域", text: $customSkill)
                            .submitLabel(.done)
                            .focused($isCustomSkillFocused)
                            .onSubmit(addCustomSkill)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "0E0B3E"))
                    .frame(height: 43)
                    .padding(.horizontal, 20)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(Color.white.opacity(0.46), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.58), lineWidth: 1)
                    )
                    .shadow(color: RegistrationTheme.navy.opacity(0.08), radius: 18, x: 0, y: 8)
                    .frame(maxWidth: 152)

                    Text("最多选择 5 个专业领域")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "86868B"))
                        .padding(.leading, 4)
                }
            }

            ProfileFieldSection(title: "职业照片") {
                ProfessionalPhotoPicker(
                    imageData: viewModel.profileDraft.professional.heroImageData,
                    pickerItem: $photoPickerItem,
                    onDelete: viewModel.removeProfessionalPhoto
                )
                .onChange(of: photoPickerItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: PickedProfileImageData.self)?.data {
                            await MainActor.run {
                                viewModel.updateProfessionalPhotoData(data)
                            }
                        }
                        await MainActor.run {
                            photoPickerItem = nil
                        }
                    }
                }

                Text("* 照片将展示在你的职业面卡片中")
                    .font(.system(size: 12, weight: .medium).italic())
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "86868B"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("职业信息编辑")
    }

    private var allSkillOptions: [String] {
        skillOptions + viewModel.profileDraft.professional.selectedSkills.filter { !skillOptions.contains($0) }
    }

    private func addCustomSkill() {
        viewModel.addCustomSkill(customSkill)
        customSkill = ""
        isCustomSkillFocused = false
    }
}

private struct LifestyleProfileEditor: View {
    @ObservedObject var viewModel: RegistrationViewModel
    var focusedField: FocusState<ProfileCreationView.Field?>.Binding
    @State private var customInterest = ""
    @State private var photoPickerItem: PhotosPickerItem?
    @FocusState private var isCustomInterestFocused: Bool

    private let interestOptions = ["摄影", "咖啡", "徒步", "独立音乐"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileFieldSection(title: "生活态度") {
                HStack(spacing: 10) {
                    TextField("总在寻找下一家好喝的咖啡馆。", text: $viewModel.profileDraft.lifestyle.statement, axis: .vertical)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "0E0B3E"))
                        .lineLimit(1...3)
                        .focused(focusedField, equals: .statement)

                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "86868B").opacity(0.55))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 13)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 48, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .stroke(.white.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: RegistrationTheme.navy.opacity(0.05), radius: 20, x: 0, y: 4)
            }

            ProfileFieldSection(title: "兴趣爱好") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Spacer()
                        TagAddButton(title: "添加") {
                            isCustomInterestFocused = true
                        }
                        .accessibilityLabel("添加兴趣")
                    }

                    FlowTagLayout(items: allInterestOptions) { interest in
                        ProfileTag(
                            title: interest,
                            isSelected: viewModel.profileDraft.lifestyle.selectedInterests.contains(interest),
                            showsRemoveIcon: true
                        ) {
                            viewModel.toggleInterest(interest)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        TextField("添加兴趣", text: $customInterest)
                            .submitLabel(.done)
                            .focused($isCustomInterestFocused)
                            .onSubmit(addCustomInterest)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "0E0B3E"))
                    .frame(height: 43)
                    .padding(.horizontal, 20)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(Color.white.opacity(0.46), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.58), lineWidth: 1)
                    )
                    .shadow(color: RegistrationTheme.navy.opacity(0.08), radius: 18, x: 0, y: 8)
                    .frame(maxWidth: 152)
                }
            }

            ProfileFieldSection(title: "生活瞬间") {
                LifestylePhotoGrid(
                    draft: viewModel.profileDraft.lifestyle,
                    pickerItem: $photoPickerItem,
                    onDelete: viewModel.removeLifestylePhoto(at:)
                )
                .onChange(of: photoPickerItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: PickedProfileImageData.self)?.data {
                            await MainActor.run {
                                viewModel.addLifestylePhotoData(data)
                            }
                        }
                        await MainActor.run {
                            photoPickerItem = nil
                        }
                    }
                }

            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("生活信息编辑")
    }

    private var allInterestOptions: [String] {
        interestOptions + viewModel.profileDraft.lifestyle.selectedInterests.filter { !interestOptions.contains($0) }
    }

    private func addCustomInterest() {
        viewModel.addCustomInterest(customInterest)
        customInterest = ""
        isCustomInterestFocused = false
    }
}

private struct ProfilePreviewView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onBack: () -> Void
    let onCompleted: () -> Void
    @State private var isShowingLifestyle = false
    private let designWidth: CGFloat = 440

    var body: some View {
        GeometryReader { proxy in
            let canvasWidth = min(proxy.size.width, designWidth)
            let scale = canvasWidth / designWidth
            let horizontalPadding = 26 * scale
            let contentWidth = canvasWidth - horizontalPadding * 2

            ZStack {
                Color.white
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 0) {
                        HStack {
                            RegistrationTopButton(kind: .back, action: onBack)
                            Spacer()
                        }
                        .padding(.bottom, 18 * scale)

                        RegistrationFlippableProfileCard(
                            draft: viewModel.profileDraft,
                            isShowingLifestyle: $isShowingLifestyle
                        )
                        .frame(width: contentWidth)
                        .accessibilityAction(named: "翻转卡片") {
                            isShowingLifestyle.toggle()
                        }

//                        Text("左右滑动 · 切换职业面与生活面")
//                            .font(.system(size: 12, weight: .medium))
//                            .tracking(0.6)
//                            .foregroundColor(Color(hex: "191C1D").opacity(0.38))
//                            .padding(.top, 18 * scale)

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
                        .padding(.top, 26 * scale)
                        .padding(.bottom, 34)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 39 * scale)
                    .padding(.bottom, 0)
                    .frame(width: canvasWidth, alignment: .bottom)
                    .background(.white)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
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
                    .frame(width: 165, height: 45)
                    .offset(x: 70, y: 25)
                    .accessibilityHidden(true)

                Text("不止一面\n才是真实的你。")
                    .font(.system(size: 35, weight: .bold))
                    .lineSpacing(-2)
                    .foregroundColor(RegistrationTheme.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(height: 98, alignment: .topLeading)

            Text("SHOW BOTH SIDES OF YOU")
                .font(.system(size: 14, weight: .bold))
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
    @Namespace private var switcherNamespace

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                sideButton(.professional)
                sideButton(.lifestyle)
            }
        }
        .padding(isCompact ? 5 : 4)
        .frame(height: isCompact ? 46 : 48)
        .background(isCompact ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(hex: "F3F4F5")), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(isCompact ? 0.6 : 0.35), lineWidth: 1)
        )
        .shadow(color: RegistrationTheme.navy.opacity(isCompact ? 0.05 : 0.05), radius: isCompact ? 20 : 8, x: 0, y: isCompact ? 4 : 1)
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
                .frame(height: isCompact ? 36 : 40)
                .background {
                    if selection == side {
                        Capsule()
                            .fill(side == .lifestyle ? Color(hex: "FDD434") : .white)
                            .matchedGeometryEffect(id: "selectedProfileSide", in: switcherNamespace)
                            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(side.title)
        .accessibilityAddTraits(selection == side ? .isSelected : [])
    }
}

private struct ProfileGlassPanel<Content: View>: View {
    var height: CGFloat?
    var verticalPadding: CGFloat = 28
    var horizontalPadding: CGFloat = 28
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.80), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(RegistrationTheme.navy.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

private struct FlowTagLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        TagFlowLayout(horizontalSpacing: 8, verticalSpacing: 10) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

private struct TagFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 350
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0, currentX + size.width > maxWidth {
                widestRow = max(widestRow, currentX - horizontalSpacing)
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        widestRow = max(widestRow, currentX > 0 ? currentX - horizontalSpacing : 0)
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX, currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct ProfileTag: View {
    let title: String
    let isSelected: Bool
    var showsRemoveIcon = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                if showsRemoveIcon && isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color(hex: "0E0B3E"))
            .frame(height: 43)
            .padding(.horizontal, 24)
            .background(.ultraThinMaterial, in: Capsule())
            .background(
                (isSelected ? RegistrationTheme.yellow.opacity(0.54) : Color.white.opacity(0.48)),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(isSelected ? 0.70 : 0.58), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.34))
                    .frame(height: 1)
                    .padding(.horizontal, 14)
            }
            .shadow(color: RegistrationTheme.navy.opacity(isSelected ? 0.10 : 0.08), radius: 18, x: 0, y: 8)
            .shadow(color: .white.opacity(0.75), radius: 1, x: 0, y: -1)
        }
        .buttonStyle(LiquidGlassPressButtonStyle(isEnabled: true))
        .accessibilityLabel("\(title)，\(isSelected ? "已选择" : "未选择")")
    }
}

private struct TagAddButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.6)
            }
            .foregroundColor(Color(hex: "0E0B3E"))
            .frame(height: 20)
        }
        .buttonStyle(.plain)
    }
}

private struct LifestylePhotoGrid: View {
    let draft: LifestyleProfileDraft
    @Binding var pickerItem: PhotosPickerItem?
    let onDelete: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            let column = (proxy.size.width - 16) / 3
            let largeWidth = column * 2 + 8

            HStack(spacing: 8) {
                photoTile(at: 0)
                    .frame(width: largeWidth, height: 256)
                    .overlay(alignment: .topTrailing) {
                        PhotoOverlayButton(systemName: "heart", label: "收藏生活照片")
                            .padding(8)
                    }

                VStack(spacing: 8) {
                    photoTile(at: 1)
                        .frame(width: column, height: 124)

                    addTile
                        .frame(width: column, height: 124)
                }
            }
        }
        .frame(height: 256)
    }

    @ViewBuilder
    private func photoTile(at index: Int) -> some View {
        GeometryReader { tileProxy in
            ZStack(alignment: .topTrailing) {
                if let image = uiImage(at: index) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: tileProxy.size.width, height: tileProxy.size.height)
                        .clipped()
                } else if let imageName = imageName(at: index) {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: tileProxy.size.width, height: tileProxy.size.height)
                        .clipped()
                } else {
                    emptyPhoto
                        .frame(width: tileProxy.size.width, height: tileProxy.size.height)
                }
            }
            .frame(width: tileProxy.size.width, height: tileProxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(.white.opacity(0.30), lineWidth: 1)
            )
            .shadow(color: .black.opacity(index == 0 ? 0.12 : 0.04), radius: index == 0 ? 15 : 6, x: 0, y: index == 0 ? 10 : 3)
            .overlay(alignment: .topLeading) {
                if hasPhoto(at: index) {
                    Button {
                        onDelete(index)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(RegistrationTheme.navy)
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("删除第 \(index + 1) 张生活照片")
                }
            }
            .accessibilityLabel(hasPhoto(at: index) ? "生活照片 \(index + 1)" : "生活照片占位")
        }
    }

    private var addTile: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            VStack(spacing: 4) {
                Image(systemName: "camera.badge.plus")
                    .font(.system(size: 26, weight: .medium))
                Text("添加")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.6)
            }
            .foregroundColor(Color(hex: "86868B"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color(hex: "86868B").opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .shadow(color: RegistrationTheme.navy.opacity(0.05), radius: 20, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加生活照片")
    }

    private var emptyPhoto: some View {
        VStack(spacing: 6) {
            Image(systemName: "photo")
                .font(.system(size: 24, weight: .medium))
            Text("暂无照片")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Color(hex: "86868B"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func uiImage(at index: Int) -> UIImage? {
        guard index < draft.imageData.count else { return nil }
        return UIImage(data: draft.imageData[index])
    }

    private func imageName(at index: Int) -> String? {
        let demoIndex = index - draft.imageData.count
        guard demoIndex >= 0, demoIndex < draft.imageNames.count else { return nil }
        return draft.imageNames[demoIndex]
    }

    private func hasPhoto(at index: Int) -> Bool {
        uiImage(at: index) != nil || imageName(at: index) != nil
    }
}

private struct ProfessionalPhotoPicker: View {
    let imageData: Data?
    @Binding var pickerItem: PhotosPickerItem?
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomLeading) {
                    imageContent

                    LinearGradient(
                        colors: [.clear, RegistrationTheme.navy.opacity(0.42)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .accessibilityHidden(true)

                    HStack(spacing: 8) {
                        Image(systemName: imageData == nil ? "camera.badge.plus" : "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 15, weight: .semibold))
                        Text(imageData == nil ? "添加职业照片" : "替换职业照片")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.32), lineWidth: 1))
                    .padding(14)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 256)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(.white.opacity(0.30), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 15, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(imageData == nil ? "添加职业照片" : "替换职业照片")

            if imageData != nil {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(RegistrationTheme.navy)
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(10)
                .accessibilityLabel("删除职业照片")
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "camera.badge.plus")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(Color(hex: "86868B"))
                Text("添加职业照片")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "0E0B3E"))
                Text("建议上传正装或职业休闲照，展示专业的一面")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "86868B"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.50))
        }
    }
}

private struct ProfileSectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .medium))
            .tracking(1.6)
            .foregroundColor(Color(hex: "86868B"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ProfileFieldSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .tracking(0.28)
                .foregroundColor(Color(hex: "86868B"))
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func profileGlassInputStyle() -> some View {
        self
            .padding(.horizontal, 13)
            .padding(.vertical, 13)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 48, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .stroke(.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: RegistrationTheme.navy.opacity(0.05), radius: 20, x: 0, y: 4)
    }
}

private struct UnderlineTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color(hex: "0E0B3E"))
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 13)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(hex: "6B7280"))
                    .frame(height: 1)
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

private struct EditableQuoteField: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color(hex: "0E0B3E"))
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "86868B").opacity(0.5))
                        .padding(.top, 12)
                        .padding(.leading, 12)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(RegistrationTheme.navy.opacity(0.20))
                    .frame(height: 1)
            }
    }
}

private struct RegistrationBottomActionBar: View {
    let errorMessage: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            InlineValidationMessage(message: errorMessage)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: action) {
                HStack(spacing: 8) {
                    Text("预览我的卡片")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "08062D"), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: Color(hex: "08062D").opacity(0.26), radius: 18, x: 0, y: 12)
                .shadow(color: Color(hex: "08062D").opacity(0.18), radius: 7, x: 0, y: 4)
            }
            .buttonStyle(LiquidGlassPressButtonStyle(isEnabled: true))
            .accessibilityLabel("预览我的卡片")
        }
        .padding(.horizontal, 24)
        .padding(.top, 25)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(RegistrationTheme.navy.opacity(0.10))
                .frame(height: 1)
        }
    }
}

private struct PhotoOverlayButton: View {
    let systemName: String
    let label: String

    var body: some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(RegistrationTheme.navy)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct RegistrationFlippableProfileCard: View {
    let draft: RegistrationProfileDraft
    @Binding var isShowingLifestyle: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        ZStack {
            FinalProfessionalProfileCard(draft: draft.professional)
                .opacity(isShowingLifestyle ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isShowingLifestyle && !reduceMotion ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.72
                )

            FinalLifestyleProfileCard(draft: draft.lifestyle, name: draft.professional.name)
                .opacity(isShowingLifestyle ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isShowingLifestyle && !reduceMotion ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.72
                )
        }
        .frame(height: isShowingLifestyle ? 1350 : 1100)
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : Double(dragTranslation / 18)),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.9
        )
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .easeInOut(duration: 0.58), value: isShowingLifestyle)
        .gesture(flipGesture)
        .accessibilityLabel(isShowingLifestyle ? "生活面预览卡片" : "职业面预览卡片")
        .accessibilityHint("左右滑动可切换职业面和生活面")
    }

    private var flipGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > 64 else { return }
                withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .easeInOut(duration: 0.58)) {
                    isShowingLifestyle.toggle()
                }
            }
    }
}

private struct FinalProfessionalProfileCard: View {
    let draft: ProfessionalProfileDraft

    private var skills: [String] {
        Array((draft.selectedSkills.isEmpty ? ["产品设计"] : draft.selectedSkills).prefix(5))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 35, style: .continuous)
                    .fill(.white.opacity(0.60))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 35, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 35, style: .continuous)
                            .stroke(RegistrationTheme.navy.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: RegistrationTheme.navy.opacity(0.08), radius: 40, x: 0, y: 10)

                VStack(spacing: 0) {
                    FinalCardHeroImage(
                        imageData: draft.heroImageData,
                        fallbackImageName: draft.heroImageName,
                        height: 464,
                        cornerRadius: 35
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(draft.name.isEmpty ? "我的名片" : draft.name)
                                    .font(.system(size: 24, weight: .medium))
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(Color(hex: "3BA7FF"))
                            }
                            Text(draft.currentIdentity.isEmpty ? "YoLink 用户" : draft.currentIdentity)
                                .font(.system(size: 14, weight: .medium))
                                .tracking(0.28)
                                .opacity(0.9)
                            Text(draft.bio.isEmpty ? "打造平衡实用与美感的数字体验。" : draft.bio)
                                .font(.system(size: 12, weight: .medium))
                                .tracking(0.6)
                                .lineLimit(2)
                                .opacity(0.82)
                        }

                        Spacer()

                        FinalConnectButton(style: .navy)
                    }

                    FinalStatsRow(items: [
                        ("briefcase", "\(max(skills.count, 1)) 项领域"),
                        ("location", draft.region.isEmpty ? "当前位置" : draft.region)
                    ])

                    FinalInfoRow(
                        icon: "graduationcap",
                        title: draft.schoolOrCompany.isEmpty ? "学校" : draft.schoolOrCompany,
                        subtitle: draft.currentIdentity.isEmpty ? "职业方向" : draft.currentIdentity
                    )

                    FinalCardSection(title: "核心专业领域") {
                        FinalCompactTagFlow(items: skills, foreground: .white, background: RegistrationTheme.navy)
                    }
                    .padding(.top, 32)

                    FinalCardSection(title: "最近动态", trailing: "查看全部") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            FinalMomentTile(imageName: "CardBG1", title: "设计系统实践", subtitle: "案例研究 · 2024")
                            FinalMomentTile(imageName: "CardBG2", title: "AI 的未来", subtitle: "研究 · 2023")
                            FinalMomentTile(imageName: "ProfessionalPic", title: "工作空间", subtitle: "项目记录 · 2023")
                            FinalMomentTile(imageName: "CardBG3", title: "互联世界", subtitle: "品牌标识 · 2022")
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 64)
                }
                .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
            }
            .frame(height: 1040)

//            FinalFlipHint(text: "切换至生活视角", systemName: "chevron.right")
                .padding(.top, 32)
        }
    }
}

private struct FinalLifestyleProfileCard: View {
    let draft: LifestyleProfileDraft
    let name: String

    private var interests: [String] {
        Array((draft.selectedInterests.isEmpty ? ["摄影", "咖啡", "徒步", "独立音乐"] : draft.selectedInterests).prefix(6))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .fill(.white.opacity(0.60))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 48, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 48, style: .continuous)
                            .stroke(RegistrationTheme.navy.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: RegistrationTheme.navy.opacity(0.06), radius: 34, x: 0, y: 14)

                VStack(spacing: 0) {
                    FinalCardHeroImage(
                        imageData: draft.imageData.first,
                        fallbackImageName: draft.imageNames.first ?? "LifePic",
                        height: 466,
                        cornerRadius: 48
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(name.isEmpty ? "我的生活面" : name)
                                    .font(.system(size: 24, weight: .medium))
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(RegistrationTheme.yellow)
                            }
                            Text(draft.statement.isEmpty ? "总在寻找下一家好喝的咖啡馆。" : draft.statement)
                                .font(.system(size: 16, weight: .medium))
                                .lineLimit(2)
                                .opacity(0.92)
                        }

                        Spacer()

                        FinalConnectButton(style: .yellow)
                    }

                    FinalStatsRow(items: [
                        ("heart", "1.2k 点赞"),
                        ("location", "我的生活")
                    ])

                    FinalCardSection(title: "热爱") {
                        FinalCompactTagFlow(items: interests, foreground: Color(hex: "191C1D"), background: .clear)
                    }
                    .padding(.top, 32)

                    FinalCardSection(title: "生活瞬间") {
                        VStack(spacing: 12) {
                            FinalLifestylePhotoTile(data: draft.imageData[safe: 0], imageName: draft.imageNames[safe: 0] ?? "LifePic", height: 190)
                            FinalLifestylePhotoTile(data: draft.imageData[safe: 1], imageName: draft.imageNames[safe: 1] ?? "life2", height: 230)
                            FinalLifestylePhotoTile(data: draft.imageData[safe: 2], imageName: draft.imageNames[safe: 2] ?? "life3", height: 230)
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 64)
                }
                .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
            }
            .frame(height: 1290)

            //FinalFlipHint(text: "切换至职业视角", systemName: "chevron.left")
                .padding(.top, 32)
        }
    }
}

private enum FinalConnectButtonStyle {
    case navy
    case yellow
}

private struct FinalConnectButton: View {
    let style: FinalConnectButtonStyle

    var body: some View {
        Text("建立\n联系")
            .font(.system(size: 14, weight: .medium))
            .tracking(0.28)
            .multilineTextAlignment(.center)
            .foregroundColor(style == .navy ? .white : Color(hex: "0E0B3E"))
            .lineLimit(2)
            .frame(width: 116, height: 50)
            .background(style == .navy ? Color(hex: "0E0B3E") : Color(hex: "FDD434"), in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 15, x: 0, y: 10)
    }
}

private struct FinalCardHeroImage<Overlay: View>: View {
    let imageData: Data?
    let fallbackImageName: String
    let height: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let overlay: Overlay

    var body: some View {
        ZStack(alignment: .bottom) {
            FinalProfileImage(data: imageData, imageName: fallbackImageName)
                .frame(height: height)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.0), location: 0.20),
                    .init(color: .black.opacity(0.30), location: 0.55),
                    .init(color: .black.opacity(0.70), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 16) {
                overlay
            }
            .foregroundColor(.white)
            .padding(32)
        }
        .frame(height: height)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: cornerRadius,
                style: .continuous
            )
        )
    }
}

private struct FinalProfileImage: View {
    let data: Data?
    let imageName: String

    var body: some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FinalStatsRow: View {
    let items: [(String, String)]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(items, id: \.1) { item in
                HStack(spacing: 4) {
                    Image(systemName: item.0)
                        .font(.system(size: 12, weight: .medium))
                    Text(item.1)
                        .font(.system(size: 12, weight: .medium))
                        .tracking(0.6)
                }
                .foregroundColor(Color(hex: "0E0B3E"))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(.white.opacity(0.40))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RegistrationTheme.navy.opacity(0.10))
                .frame(height: 1)
        }
    }
}

private struct FinalInfoRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: "EDEEEF"))
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(RegistrationTheme.navy)
                )
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "191C1D"))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "86868B"))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RegistrationTheme.navy.opacity(0.10))
                .frame(height: 1)
        }
    }
}

private struct FinalCardSection<Content: View>: View {
    let title: String
    var trailing: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(1.4)
                    .foregroundColor(Color(hex: "86868B"))
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "0E0B3E"))
                }
            }

            content
        }
        .padding(.horizontal, 32)
    }
}

private struct FinalCompactTagFlow: View {
    let items: [String]
    let foreground: Color
    let background: Color

    var body: some View {
        TagFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(0.28)
                    .foregroundColor(foreground)
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(background == .clear ? Color.clear : background, in: Capsule())
            }
        }
    }
}

private struct FinalMomentTile: View {
    let imageName: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 134)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(RegistrationTheme.navy.opacity(0.10), lineWidth: 1)
                )

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "191C1D"))
                .lineLimit(1)
                .padding(.top, 8)
            Text(subtitle)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(Color(hex: "86868B"))
                .lineLimit(1)
        }
    }
}

private struct FinalLifestylePhotoTile: View {
    let data: Data?
    let imageName: String
    let height: CGFloat

    var body: some View {
        FinalProfileImage(data: data, imageName: imageName)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(RegistrationTheme.navy.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

private struct FinalFlipHint: View {
    let text: String
    let systemName: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .tracking(0.6)
        }
        .foregroundColor(Color(hex: "191C1D").opacity(0.40))
        .frame(maxWidth: .infinity)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
                .fill(isEnabled ? background.opacity(0.94) : RegistrationTheme.navy.opacity(0.58))
                .overlay(surfaceTint)
        } else if #available(iOS 26.0, *) {
            buttonShape
                .fill(.clear)
                .glassEffect(
                    .regular
                        .tint((isEnabled ? background : RegistrationTheme.navy).opacity(isEnabled ? 0.48 : 0.34))
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
            .fill(isEnabled ? background.opacity(0.72) : RegistrationTheme.navy.opacity(0.52))
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(isEnabled ? 0.22 : 0.14),
                        .white.opacity(0.04),
                        RegistrationTheme.navy.opacity(isEnabled ? 0.28 : 0.30)
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
        viewModel.profileDraft.professional.bio = ""
        viewModel.profileCreationError = "请填写职业简介"
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
    let draft: RegistrationProfileDraft = {
        var draft = RegistrationProfileDraft()
        draft.professional.name = "陈苏菲"
        draft.professional.currentIdentity = "YoLink 资深产品设计师"
        draft.professional.schoolOrCompany = "斯坦福大学"
        draft.professional.region = "加州 旧金山"
        draft.professional.bio = "打造平衡实用与美感的数字体验。专注于简化复杂系统。"
        draft.professional.selectedSkills = ["产品设计", "AI/机器学习设计", "策略", "原型制作", "用户研究"]
        draft.lifestyle.statement = "总在寻找下一家好喝的咖啡馆。"
        draft.lifestyle.selectedInterests = ["摄影", "咖啡", "徒步", "独立音乐"]
        return draft
    }()

    RegistrationFlippableProfileCard(
        draft: draft,
        isShowingLifestyle: .constant(true)
    )
    .padding(.horizontal, 26)
    .padding(.top, 39)
    .padding(.bottom, 0)
    .frame(width: 440, alignment: .bottom)
    .background(.white)
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
