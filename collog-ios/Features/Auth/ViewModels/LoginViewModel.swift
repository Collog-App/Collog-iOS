import AuthenticationServices
import SwiftUI

@Observable
final class LoginViewModel {
    var name = ""
    var role: UserRoleOption = .child
    var isSubmitting = false
    var isLoadingChallenge = false
    var errorMessage: String?
    private var challenge: AppleLoginChallenge?
    private var challengeExpiresAt: Date?
    private var requestState: String?
    private var requestRole: String?

    var canSignIn: Bool {
        challenge != nil && !isSubmitting && !isLoadingChallenge
    }

    func prepareChallenge(using environment: AppEnvironment, clearError: Bool = true) async {
        guard !isSubmitting, !isLoadingChallenge else { return }
        if clearError { errorMessage = nil }
        challenge = nil
        challengeExpiresAt = nil
        isLoadingChallenge = true
        defer { isLoadingChallenge = false }
        do {
            let response = try await environment.api.appleLoginChallenge()
            guard response.expiresIn > 0, !response.nonce.isEmpty, !response.challengeId.isEmpty else {
                throw APIError.decoding("Invalid Apple login challenge")
            }
            challenge = response
            challengeExpiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshChallengeIfNeeded(using environment: AppEnvironment) async {
        guard !isSubmitting, let expiry = challengeExpiresAt, expiry <= Date().addingTimeInterval(10) else {
            return
        }
        await prepareChallenge(using: environment, clearError: false)
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        errorMessage = nil
        guard let challenge, let expiry = challengeExpiresAt, expiry > Date() else {
            self.challenge = nil
            errorMessage = "로그인 준비 시간이 지났어요. 다시 시도해주세요."
            return
        }
        isSubmitting = true
        requestState = UUID().uuidString
        requestRole = role.rawValue
        request.requestedScopes = [.fullName]
        request.nonce = challenge.nonce
        request.state = requestState
    }

    func complete(
        _ result: Result<ASAuthorization, Error>,
        using environment: AppEnvironment
    ) async -> Bool {
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let requestState,
                  credential.state == requestState,
                  let challenge,
                  let requestRole,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  !token.isEmpty else {
                throw APIError.transport("Apple 로그인 정보를 확인하지 못했어요. 다시 시도해주세요.")
            }
            let enteredName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let appleName = credential.fullName.map {
                PersonNameComponentsFormatter().string(from: $0)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } ?? ""
            let displayName = enteredName.isEmpty ? appleName : enteredName
            if name.isEmpty { name = displayName }
            let response = try await environment.api.loginWithApple(
                identityToken: token,
                challengeId: challenge.challengeId,
                role: requestRole,
                name: displayName.isEmpty ? nil : displayName
            )
            try environment.session.apply(response)
            clearRequest()
            return true
        } catch {
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
            clearRequest()
            await prepareChallenge(using: environment, clearError: false)
            return false
        }
    }

    private func clearRequest() {
        challenge = nil
        challengeExpiresAt = nil
        requestState = nil
        requestRole = nil
        isSubmitting = false
    }
}
