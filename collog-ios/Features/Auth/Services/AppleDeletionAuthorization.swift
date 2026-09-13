import AuthenticationServices
import UIKit

@MainActor
final class AppleDeletionAuthorization: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleDeletionBody, Error>?
    private var controller: ASAuthorizationController?
    private var challenge: AppleLoginChallenge?
    private var expectedState = ""
    private var expectedUser = ""
    private var window: UIWindow?

    func authorize(challenge: AppleLoginChallenge, user: String) async throws -> AppleDeletionBody {
        guard continuation == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: \.isKeyWindow) else {
            throw APIError.transport("화면을 다시 표시한 후 시도해주세요.")
        }
        self.window = window
        self.challenge = challenge
        expectedUser = user
        expectedState = UUID().uuidString
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.nonce = challenge.nonce
        request.state = expectedState
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        window ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization auth: ASAuthorization) {
        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              credential.user == expectedUser, credential.state == expectedState,
              let challenge,
              let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8),
              let codeData = credential.authorizationCode, let code = String(data: codeData, encoding: .utf8),
              !token.isEmpty, !code.isEmpty else {
            finish(.failure(APIError.transport("현재 계정으로 Apple 인증을 다시 진행해주세요.")))
            return
        }
        finish(.success(AppleDeletionBody(
            identityToken: token, challengeId: challenge.challengeId, authorizationCode: code
        )))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<AppleDeletionBody, Error>) {
        let continuation = continuation
        self.continuation = nil
        controller = nil
        challenge = nil
        window = nil
        continuation?.resume(with: result)
    }
}
