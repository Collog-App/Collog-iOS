//
//  AuthSession.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI
import Security
import AuthenticationServices

@Observable
final class AuthSession {
    enum Key {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
        static let user = "auth.user"
    }

    private let defaults: UserDefaults
    @ObservationIgnored private var refreshTask: Task<String, Error>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored var onAccountChanged: (() -> Void)?

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var user: APIUser?
    private(set) var storageError: String?

    var isAuthenticated: Bool { accessToken != nil }
    var familyId: String? { user?.familyId }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accessToken = defaults.string(forKey: Key.accessToken)
        refreshToken = defaults.string(forKey: Key.refreshToken)
        user = defaults.data(forKey: Key.user).flatMap { try? JSONDecoder().decode(APIUser.self, from: $0) }
        do {
            if let saved = try CredentialStore.read() {
                accessToken = saved.accessToken
                refreshToken = saved.refreshToken
                user = saved.user
            } else if let accessToken, let refreshToken, let user {
                try CredentialStore.write(
                    TokenResponse(accessToken: accessToken, refreshToken: refreshToken, user: user)
                )
            }
        } catch {
            accessToken = nil
            refreshToken = nil
            user = nil
            storageError = error.localizedDescription
        }
        [Key.accessToken, Key.refreshToken, Key.user].forEach(defaults.removeObject(forKey:))
    }

    func apply(_ response: TokenResponse) throws {
        try CredentialStore.write(response)
        storageError = nil
        if user?.id != response.user.id || user?.role != response.user.role {
            generation = UUID()
            refreshTask?.cancel()
            refreshTask = nil
            onAccountChanged?()
        }
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        user = response.user
    }

    func signOut() {
        generation = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        do {
            try CredentialStore.delete()
        } catch {
            storageError = error.localizedDescription
        }
        accessToken = nil
        refreshToken = nil
        user = nil

        [Key.accessToken, Key.refreshToken, Key.user].forEach(defaults.removeObject(forKey:))
        onAccountChanged?()
    }

    func checkAppleCredential(using baseURL: URL) async {
        guard let appleUserId = user?.appleUserId else { return }
        let currentGeneration = generation
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: appleUserId)
            guard currentGeneration == generation, user?.appleUserId == appleUserId else { return }
            if state == .revoked || state == .notFound {
                let refreshToken = refreshToken
                signOut()
                if let refreshToken {
                    let api = CollogAPI(client: CollogAPIClient(baseURL: baseURL))
                    try? await api.logout(refreshToken: refreshToken)
                }
            }
        } catch {
            return
        }
    }

    func joinFamily(_ familyId: String) throws {
        guard let accessToken, let refreshToken, var user else { throw APIError.unauthenticated }
        user.familyId = familyId
        try apply(TokenResponse(accessToken: accessToken, refreshToken: refreshToken, user: user))
    }

    func updateUser(_ user: APIUser) throws {
        guard self.user?.id == user.id, let accessToken, let refreshToken else {
            throw APIError.unauthenticated
        }
        try apply(TokenResponse(accessToken: accessToken, refreshToken: refreshToken, user: user))
    }

    func refresh(using baseURL: URL) async throws -> String {
        if let refreshTask { return try await refreshTask.value }
        guard let refreshToken else {
            signOut()
            throw APIError.unauthenticated
        }
        let currentGeneration = generation
        let task = Task { @MainActor in
            let api = CollogAPI(client: CollogAPIClient(baseURL: baseURL))
            do {
                let response = try await api.refreshSession(refreshToken: refreshToken)
                guard currentGeneration == generation else { throw APIError.unauthenticated }
                var refreshedUser = response.user
                if user?.id == refreshedUser.id, user?.role == refreshedUser.role {
                    refreshedUser.familyId = user?.familyId ?? refreshedUser.familyId
                }
                try apply(TokenResponse(
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken,
                    user: refreshedUser
                ))
                return response.accessToken
            } catch APIError.unauthenticated {
                if currentGeneration == generation { signOut() }
                throw APIError.unauthenticated
            }
        }
        refreshTask = task
        defer {
            if currentGeneration == generation { refreshTask = nil }
        }
        return try await task.value
    }
}

private enum CredentialStore {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.dohyeoplim.collog-ios",
            kSecAttrAccount as String: "session"
        ]
    }

    static func read() throws -> TokenResponse? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw APIError.transport("저장된 로그인 정보를 가져오지 못했어요")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    static func write(_ response: TokenResponse) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(response),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw APIError.transport("로그인 정보를 안전하게 저장하지 못했어요")
        }
    }

    static func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIError.transport("저장된 로그인 정보를 삭제하지 못했어요")
        }
    }
}
