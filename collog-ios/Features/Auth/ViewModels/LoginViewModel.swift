//
//  LoginViewModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class LoginViewModel {
    enum Step {
        case identity
        case code
    }

    var step: Step = .identity
    var phone = ""
    var name = ""
    var role: UserRoleOption = .child
    var code = ""
    var isSubmitting = false
    var errorMessage: String?

    var canRequestCode: Bool {
        phone.count >= 8 && !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSubmitting
    }

    var canVerify: Bool { code.count == 6 && !isSubmitting }

    func requestCode(using environment: AppEnvironment) async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await environment.api.requestOtp(phone: phone, role: role.rawValue, name: name)
            step = .code
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    func verify(using environment: AppEnvironment) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        do {
            let response = try await environment.api.verifyOtp(phone: phone, code: code)
            environment.session.apply(response)
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}
