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

    func advance(to step: Step) {
        self.step = step
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
            step = .login
            return
        }
        if user.role == UserRoleOption.parent.rawValue, user.familyId == nil {
            step = .invitation
            return
        }

        do {
            let consent = try await environment.api.myConsent()
            guard environment.session.user == user, !environment.settings.isGuestMode else { return }
            guard consent.isCurrent else {
                step = .consent
                return
            }
            guard consent.isGranted, user.role == UserRoleOption.parent.rawValue else {
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
            step = profile.conditions.isEmpty ? .profile : .ready
        } catch {
            guard environment.session.user == user, !environment.settings.isGuestMode else { return }
            step = .ready
        }
    }
}
