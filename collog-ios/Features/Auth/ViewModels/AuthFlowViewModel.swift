//
//  AuthFlowViewModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class AuthFlowViewModel {
    enum Step: Hashable {
        case launching
        case onboarding
        case login
        case invitation
        case consent
        case profile
        case ready
    }

    private(set) var step: Step = .launching
    /// 로그인 직후 한 번, 아직 아무와도 연결되지 않은 사람에게 초대 코드 입력을 권한다(건너뛸 수 있다).
    private(set) var offersInvitation = false

    func advance(to step: Step) {
        self.step = step
    }

    func completeInvitation() {
        offersInvitation = false
    }

    func resolve(using environment: AppEnvironment) async {
        guard environment.settings.onboardingCompleted else {
            step = .onboarding
            return
        }
        guard !environment.settings.isGuestMode else {
            step = .ready
            return
        }
        guard environment.session.isAuthenticated, let user = environment.session.user else {
            offersInvitation = true
            step = .login
            return
        }
        if offersInvitation {
            let isAlone = await isAlone(user, using: environment)
            guard environment.session.user == user, !environment.settings.isGuestMode else { return }
            if isAlone {
                step = .invitation
                return
            }
        }

        do {
            let consent = try await environment.api.myConsent()
            guard environment.session.user == user, !environment.settings.isGuestMode else { return }
            guard consent.isCurrent else {
                step = .consent
                return
            }
            guard consent.isGranted else {
                step = .ready
                return
            }
        } catch {
            guard environment.session.user == user, !environment.settings.isGuestMode else { return }
            step = .consent
            return
        }

        do {
            let profile = try await environment.api.profile(parentId: user.id)
            guard environment.session.user == user, !environment.settings.isGuestMode else { return }
            step = profile.hasCompletedSetup ? .ready : .profile
        } catch {
            guard environment.session.user == user, !environment.settings.isGuestMode else { return }
            step = .ready
        }
    }

    /// 가족이 없거나 자기 혼자뿐인 가족이면 초대 코드로 다른 가족에 들어갈 수 있다. 확인하지 못하면 묻지 않는다.
    private func isAlone(_ user: APIUser, using environment: AppEnvironment) async -> Bool {
        guard let familyId = user.familyId else { return true }
        guard let members = try? await environment.api.members(familyId: familyId) else { return false }
        return !members.contains { $0.userId != nil && $0.userId != user.id }
    }
}
