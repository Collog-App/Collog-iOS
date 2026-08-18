//
//  AuthSession.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class AuthSession {
    enum Key {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
        static let user = "auth.user"
    }

    private let defaults: UserDefaults

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var user: APIUser?

    var isAuthenticated: Bool { accessToken != nil }
    var familyId: String? { user?.familyId }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accessToken = defaults.string(forKey: Key.accessToken)
        refreshToken = defaults.string(forKey: Key.refreshToken)
        user = defaults.data(forKey: Key.user).flatMap { try? JSONDecoder().decode(APIUser.self, from: $0) }
    }

    func apply(_ response: TokenResponse) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        user = response.user

        defaults.set(response.accessToken, forKey: Key.accessToken)
        defaults.set(response.refreshToken, forKey: Key.refreshToken)
        defaults.set(try? JSONEncoder().encode(response.user), forKey: Key.user)
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        user = nil

        [Key.accessToken, Key.refreshToken, Key.user].forEach(defaults.removeObject(forKey:))
    }
}
