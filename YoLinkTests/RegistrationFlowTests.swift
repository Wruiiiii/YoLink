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

        #expect(viewModel.step == .basicInformation)
        #expect(viewModel.areCredentialsCompleted)
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
}
