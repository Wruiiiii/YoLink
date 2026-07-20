import Testing
@testable import YoLink

@MainActor
struct RegistrationFlowTests {
    @Test func phoneFormattingFiltersNonDigitsAndLimitsLength() {
        #expect(RegistrationViewModel.digitsOnly("138 8888-8888 abc 99", limit: 11) == "13888888888")
    }

    @Test func demoPhoneValidationAllowsOnlyConfiguredPhone() {
        let service = AuthMockService()

        #expect(service.validatePhone("13888888888") == nil)
        #expect(service.validatePhone("13800000000") == "当前 Demo 请使用 13888888888")
        #expect(service.validatePhone("138") == "请输入正确的 11 位手机号")
    }

    @Test func verificationCodeValidationUsesMockCode() {
        let service = AuthMockService()

        #expect(service.validateVerificationCode("123456"))
        #expect(!service.validateVerificationCode("000000"))
    }

    @Test func passwordRulesValidateLengthLettersNumbersAndMatch() {
        let service = AuthMockService()

        #expect(service.validatePassword("", confirmation: "") == .empty)
        #expect(service.validatePassword("123", confirmation: "123") == .tooShort)
        #expect(service.validatePassword("12345678", confirmation: "12345678") == .missingLetter)
        #expect(service.validatePassword("yolinkabc", confirmation: "yolinkabc") == .missingNumber)
        #expect(service.validatePassword("123yolink！", confirmation: "123yolink?") == .mismatch)
        #expect(service.validatePassword("123yolink?", confirmation: "123yolink?") == .mockMismatch)
    }

    @Test func passwordAcceptsFullWidthAndHalfWidthExclamationMarks() {
        let service = AuthMockService()

        #expect(RegistrationMockData.normalizePassword("123yolink!") == "123yolink！")
        #expect(service.validatePassword("123yolink！", confirmation: "123yolink！") == nil)
        #expect(service.validatePassword("123yolink!", confirmation: "123yolink!") == nil)
    }

    @Test func registrationStepSwitchesAfterValidCodeAndPassword() {
        let viewModel = RegistrationViewModel()

        viewModel.phoneNumber = "13888888888"
        viewModel.submitPhone()
        viewModel.verificationCode = "123456"
        viewModel.submitCode()

        #expect(viewModel.step == .createPassword)

        viewModel.password = "123yolink!"
        viewModel.confirmPassword = "123yolink!"
        viewModel.submitPassword()

        #expect(viewModel.step == .dualCardIntroduction)
        #expect(viewModel.areCredentialsCompleted)
    }

    @Test func credentialsCompletionMovesIntoDualCardIntroduction() {
        let viewModel = verifiedPasswordViewModel()

        #expect(viewModel.step == .dualCardIntroduction)
        viewModel.startDualProfileCreation()
        #expect(viewModel.step == .profileCreation)
    }

    @Test func professionalProfileMinimumFieldsAreValidated() {
        var draft = ProfessionalProfileDraft()
        draft.name = ""
        #expect(RegistrationProfileValidator.professionalError(for: draft) == "请输入姓名")

        draft.name = "林知夏"
        draft.currentIdentity = ""
        draft.schoolOrCompany = ""
        #expect(RegistrationProfileValidator.professionalError(for: draft) == "请填写你的职业身份")

        draft.currentIdentity = "产品设计师"
        draft.bio = ""
        #expect(RegistrationProfileValidator.professionalError(for: draft) == "请添加一段职业简介")

        draft.bio = "设计人与技术之间的连接。"
        #expect(RegistrationProfileValidator.professionalError(for: draft) == nil)
    }

    @Test func lifestyleProfileMinimumFieldsAreValidated() {
        var draft = LifestyleProfileDraft()
        draft.selectedInterests = []
        #expect(RegistrationProfileValidator.lifestyleError(for: draft) == "请至少选择一个兴趣")

        draft.selectedInterests = ["摄影"]
        draft.imageNames = []
        #expect(RegistrationProfileValidator.lifestyleError(for: draft) == "请添加一张生活照片")

        draft.imageNames = ["LifePic"]
        draft.statement = ""
        #expect(RegistrationProfileValidator.lifestyleError(for: draft) == "请写一句关于生活中的你")

        draft.statement = "总在寻找下一家好喝的咖啡馆。"
        #expect(RegistrationProfileValidator.lifestyleError(for: draft) == nil)
    }

    @Test func profileDraftSurvivesSideSwitchingAndPreviewUsesLatestData() {
        let viewModel = verifiedPasswordViewModel()
        viewModel.startDualProfileCreation()

        viewModel.profileDraft.professional.name = "王小明"
        viewModel.profileDraft.professional.currentIdentity = "AI 产品经理"
        viewModel.profileDraft.professional.bio = "把复杂技术变成日常可用的产品。"
        viewModel.toggleSkill("产品设计")
        viewModel.switchProfileSide(to: .lifestyle)
        viewModel.profileDraft.lifestyle.statement = "周末喜欢骑车看城市。"
        viewModel.toggleInterest("摄影")
        viewModel.switchProfileSide(to: .professional)

        #expect(viewModel.profileDraft.lifestyle.statement == "周末喜欢骑车看城市。")
        #expect(viewModel.previewProfileCard.name == "王小明")
        #expect(viewModel.previewProfileCard.introduction == "把复杂技术变成日常可用的产品。")
    }

    @Test func cannotPreviewUntilRequiredProfileFieldsAreComplete() {
        let viewModel = verifiedPasswordViewModel()
        viewModel.startDualProfileCreation()
        viewModel.profileDraft.professional.name = ""
        viewModel.previewProfile()

        #expect(viewModel.step == .profileCreation)
        #expect(viewModel.editingProfileSide == .professional)
        #expect(viewModel.profileCreationError == "请输入姓名")
    }

    @Test func previewAndReturnKeepsDraftData() {
        let viewModel = completedProfileViewModel()
        viewModel.previewProfile()
        #expect(viewModel.step == .profilePreview)

        viewModel.goBack()
        #expect(viewModel.step == .profileCreation)
        #expect(viewModel.profileDraft.professional.name == "林知夏")
        #expect(viewModel.profileDraft.lifestyle.statement == "总在寻找下一家好喝的咖啡馆。")
    }

    @Test func completingRegistrationClearsPasswordAndMarksCompletion() {
        let viewModel = completedProfileViewModel()
        viewModel.previewProfile()
        viewModel.password = "should clear"
        viewModel.confirmPassword = "should clear"
        viewModel.completeRegistration()

        #expect(viewModel.step == .completed)
        #expect(viewModel.isRegistrationCompleted)
        #expect(viewModel.password.isEmpty)
        #expect(viewModel.confirmPassword.isEmpty)
    }

    @Test func editingPhoneClearsVerificationState() {
        let viewModel = RegistrationViewModel()

        viewModel.phoneNumber = "13888888888"
        viewModel.verificationCode = "123456"
        viewModel.submitCode()
        viewModel.editPhone()

        #expect(viewModel.verificationCode.isEmpty)
        #expect(!viewModel.isPhoneVerified)
        #expect(viewModel.codeError == nil)
    }

    private func verifiedPasswordViewModel() -> RegistrationViewModel {
        let viewModel = RegistrationViewModel()
        viewModel.phoneNumber = "13888888888"
        viewModel.submitPhone()
        viewModel.verificationCode = "123456"
        viewModel.submitCode()
        viewModel.password = "123yolink!"
        viewModel.confirmPassword = "123yolink!"
        viewModel.submitPassword()
        return viewModel
    }

    private func completedProfileViewModel() -> RegistrationViewModel {
        let viewModel = verifiedPasswordViewModel()
        viewModel.startDualProfileCreation()
        viewModel.profileDraft.professional.name = "林知夏"
        viewModel.profileDraft.professional.currentIdentity = "产品设计师"
        viewModel.profileDraft.professional.bio = "设计人与技术之间的连接。"
        viewModel.profileDraft.professional.selectedSkills = ["产品设计"]
        viewModel.profileDraft.lifestyle.statement = "总在寻找下一家好喝的咖啡馆。"
        viewModel.profileDraft.lifestyle.selectedInterests = ["摄影"]
        viewModel.profileDraft.lifestyle.imageNames = ["LifePic"]
        return viewModel
    }
}
