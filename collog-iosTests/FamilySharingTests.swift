//
//  FamilySharingTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 가족별 공유 설정(`GET/PUT /v1/account/sharing`): 내 리포트·타임라인을 구성원마다 보일지.
@MainActor
struct FamilySharingTests {
    @Test
    func loadReadsEveryOtherFamilyMember() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, sharesBody()) }
        let model = FamilySharingModel()
        #expect(!model.hasLoaded)

        await model.load(using: fixture.environment)

        #expect(fixture.paths == ["/v1/account/sharing"])
        #expect(model.hasLoaded)
        #expect(model.shares.map(\.viewerUserId) == ["mother", "owner"])
        #expect(model.shares.map(\.viewerName) == ["어머니", "가족 만든 사람"])
        #expect(model.shares.map(\.report) == [true, true])
        #expect(model.shares.map(\.timeline) == [true, false])
        // 관계가 비어 있는 사람(가족을 만든 사람)은 이름만 보인다
        #expect(model.shares.map({ FamilyRelation.title($0.relation ?? "") }) == ["어머니", nil])
    }

    @Test
    func emptyFamilyLoadsAsEmptyList() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, #"{"shares":[]}"#) }
        let model = FamilySharingModel()
        await model.load(using: fixture.environment)
        #expect(model.hasLoaded)
        #expect(model.shares.isEmpty)
        #expect(model.errorText == nil)
    }

    @Test
    func failedLoadShowsServerMessageAndCanRetry() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (500, #"{"code":"ERROR","message":"잠시 후 다시 시도해주세요"}"#) }
        let model = FamilySharingModel()
        await model.load(using: fixture.environment)
        #expect(!model.hasLoaded)
        #expect(model.errorText == "잠시 후 다시 시도해주세요")

        fixture.respond = { _ in (200, sharesBody()) }
        await model.load(using: fixture.environment)
        #expect(model.hasLoaded)
        #expect(model.errorText == nil)
    }

    @Test
    func toggleSavesOnlyTheChangedMemberAndKeepsServerAnswer() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, sharesBody()) }
        let model = FamilySharingModel()
        await model.load(using: fixture.environment)

        var sent: [(method: String, body: [String: Any])] = []
        fixture.respond = { request in
            sent.append((request.httpMethod ?? "", Self.body(request)))
            // 화면이 바로 바뀐 뒤에 저장한다
            #expect(model.shares.first?.report == false)
            #expect(model.isSubmitting)
            return (200, sharesBody(motherReport: false))
        }
        await model.update("mother", report: false, using: fixture.environment)

        #expect(fixture.paths.last == "/v1/account/sharing")
        #expect(sent.map(\.method) == ["PUT"])
        let rows = try #require(sent.first?.body["shares"] as? [[String: Any]])
        #expect(rows.count == 1)
        #expect(rows.first?["viewerUserId"] as? String == "mother")
        #expect(rows.first?["report"] as? Bool == false)
        #expect(rows.first?["timeline"] as? Bool == true)
        #expect(rows.first?.keys.sorted() == ["report", "timeline", "viewerUserId"])
        #expect(model.shares.map(\.report) == [false, true])
        #expect(model.shares.map(\.timeline) == [true, false])
        #expect(!model.isSubmitting)
        #expect(model.errorText == nil)
    }

    @Test
    func failedSaveRevertsTheSwitchAndShowsTheReason() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, sharesBody()) }
        let model = FamilySharingModel()
        await model.load(using: fixture.environment)

        fixture.respond = { _ in
            (422, #"{"code":"INVALID","message":"같은 가족 구성원에게만 공유 범위를 정할 수 있어요"}"#)
        }
        await model.update("owner", timeline: true, using: fixture.environment)

        #expect(model.shares.map(\.timeline) == [true, false])
        #expect(model.errorText == "같은 가족 구성원에게만 공유 범위를 정할 수 있어요")
        #expect(!model.isSubmitting)
    }

    @Test
    func unchangedOrUnknownMemberDoesNotCallTheServer() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, sharesBody()) }
        let model = FamilySharingModel()
        await model.load(using: fixture.environment)

        await model.update("mother", report: true, using: fixture.environment)
        await model.update("stranger", report: false, using: fixture.environment)
        #expect(fixture.paths == ["/v1/account/sharing"])
    }

    @Test
    func guestNeverCallsTheServer() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.environment.settings.isGuestMode = true
        let model = FamilySharingModel()
        await model.load(using: fixture.environment)
        await model.update("mother", report: false, using: fixture.environment)
        #expect(!model.hasLoaded)
        #expect(model.shares.isEmpty)
        #expect(fixture.paths.isEmpty)
    }

    @Test
    func updatingChangesOnlyThatMemberAndOnlyTheGivenSwitch() {
        let shares = [
            FamilyShare(viewerUserId: "a", viewerName: "A", relation: "MOTHER", report: true, timeline: true),
            FamilyShare(viewerUserId: "b", viewerName: "B", relation: nil, report: true, timeline: true)
        ]
        let reportOff = shares.updating("b", report: false)
        #expect(reportOff.map(\.report) == [true, false])
        #expect(reportOff.map(\.timeline) == [true, true])
        let timelineOff = reportOff.updating("a", timeline: false)
        #expect(timelineOff.map(\.report) == [true, false])
        #expect(timelineOff.map(\.timeline) == [false, true])
        #expect(shares.updating("missing", report: false) == shares)
    }

    // MARK: - Fixtures

    private func sharesBody(motherReport: Bool = true) -> String {
        """
        {"shares":[
          {"viewerUserId":"mother","viewerName":"어머니","relation":"MOTHER","report":\(motherReport),"timeline":true},
          {"viewerUserId":"owner","viewerName":"가족 만든 사람","relation":"","report":true,"timeline":false}
        ]}
        """
    }

    /// URLProtocol 은 본문을 스트림으로 넘긴다.
    private static func body(_ request: URLRequest) -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}
