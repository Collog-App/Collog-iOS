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

    init(settings: AppSettings = AppSettings(), session: AuthSession = AuthSession()) {
        self.settings = settings
        self.session = session
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
