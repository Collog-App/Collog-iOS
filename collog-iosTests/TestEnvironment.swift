//
//  TestEnvironment.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation
import Testing
@testable import collog_ios

@MainActor
final class MemoryCredentials: SessionCredentialStorage {
    var response: TokenResponse?

    func read() throws -> TokenResponse? { response }
    func write(_ response: TokenResponse) throws { self.response = response }
    func delete() throws { response = nil }
}

final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    @MainActor static var handlers: [String: @MainActor (URLRequest) throws -> (Int, String)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Task { @MainActor in
            do {
                let key = request.value(forHTTPHeaderField: "X-Test-Fixture") ?? ""
                let handler = try #require(Self.handlers[key])
                let (status, body) = try handler(request)
                let url = try #require(request.url)
                let response = try #require(HTTPURLResponse(
                    url: url, statusCode: status, httpVersion: nil, headerFields: nil
                ))
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(body.utf8))
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

@MainActor
final class TestEnvironment {
    let id = UUID().uuidString
    let defaults: UserDefaults
    let credentials = MemoryCredentials()
    let networkSession: URLSession
    let environment: AppEnvironment
    var paths: [String] = []
    var respond: (URLRequest) throws -> (Int, String) = { request in
        Issue.record("Unexpected request \(request.url?.path ?? "")")
        throw URLError(.unsupportedURL)
    }

    init(role: String = "PARENT", familyId: String? = "family") throws {
        defaults = try #require(UserDefaults(suiteName: id))
        defaults.set(true, forKey: AppSettings.Key.productionServerConfigured)
        defaults.set(true, forKey: AppSettings.Key.onboardingCompleted)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Test-Fixture": id]
        networkSession = URLSession(configuration: configuration)
        let session = AuthSession(
            defaults: defaults, credentialStore: credentials, networkSession: networkSession
        )
        try session.apply(TokenResponse(
            accessToken: "fixture-token", refreshToken: "fixture-refresh",
            user: APIUser(id: "me", role: role, name: "Tester", phone: nil, familyId: familyId)
        ))
        environment = AppEnvironment(
            settings: AppSettings(defaults: defaults), session: session,
            family: FamilyStore(defaults: defaults), networkSession: networkSession
        )
        FixtureURLProtocol.handlers[id] = { [weak self] request in
            guard let self else { throw URLError(.cancelled) }
            paths.append(request.url?.path ?? "")
            return try respond(request)
        }
    }

    func cleanUp() {
        respond = { _ in throw URLError(.cancelled) }
        networkSession.invalidateAndCancel()
        FixtureURLProtocol.handlers.removeValue(forKey: id)
        defaults.removePersistentDomain(forName: id)
    }

    func consent(current: Bool = true, granted: Bool = true) -> String {
        """
        {"consentId":"consent","userId":"me","documentVersion":"current","agreedItems":[],
        "status":"\(granted ? "GRANTED" : "DENIED")","isCurrent":\(current),
        "currentDocumentVersion":"current"}
        """
    }
}
