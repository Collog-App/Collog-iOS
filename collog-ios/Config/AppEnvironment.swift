//
//  AppEnvironment.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class AppEnvironment {
    let settings: AppSettings
    let session: AuthSession
    let family: FamilyStore

    init(
        settings: AppSettings = AppSettings(),
        session: AuthSession = AuthSession(),
        family: FamilyStore = FamilyStore()
    ) {
        self.settings = settings
        self.session = session
        self.family = family
    }

    func subjectParentId() async -> String? {
        guard let user = session.user else { return nil }
        if user.role == UserRoleOption.parent.rawValue { return user.id }
        guard let familyId = user.familyId else { return nil }
        let members = try? await api.members(familyId: familyId)
        return members?.first { $0.userId != nil }?.userId
    }

    var api: CollogAPI {
        CollogAPI(
            client: CollogAPIClient(
                baseURL: settings.resolvedBaseURL,
                accessToken: { [session] in session.accessToken }
            )
        )
    }
}
