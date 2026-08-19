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
        guard user.role == UserRoleOption.parent.rawValue else {
            step = .ready
            return
        }

        do {
            let consent = try await environment.api.myConsent()
            guard consent.isGranted else {
                step = .consent
                return
            }
        } catch let error as APIError {
            step = isMissingRecord(error) ? .consent : .ready
            return
        } catch {
            step = .ready
            return
        }

        do {
            let profile = try await environment.api.profile(parentId: user.id)
            step = profile.conditions.isEmpty ? .profile : .ready
        } catch {
            step = .ready
        }
    }

    private func isMissingRecord(_ error: APIError) -> Bool {
        if case let .server(status, _, _) = error { return status == 404 }
        return false
    }
}
