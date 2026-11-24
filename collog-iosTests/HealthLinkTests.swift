//
//  HealthLinkTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 건강 앱 연결 약속(2026-11-08)의 API 모양(JSON camelCase, platform HEALTHKIT)과 연결·동기화 흐름.
/// HealthKit 대신 가짜 기록을 넣는다(실기기 권한 창·실제 건강 기록은 여기서 확인할 수 없다).
@MainActor
struct HealthLinkTests {
    private let version = "health-link-2026-11-08.v1"

    @Test func linkStatusDecodesContractJSON() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { [self] _ in (200, linkJSON(connected: true, lastSyncedDay: "\"2026-11-07\"")) }
        let link = try await fixture.environment.api.healthLink()
        #expect(link.connected)
        #expect(link.consentVersion == version)
        #expect(link.connectedAt == "2026-11-08T01:02:03.123456+00:00")
        #expect(link.document?.title == "건강 앱 연결 (선택)")
        #expect(link.document?.items.count == 6)
        #expect(link.lastSyncedDay == "2026-11-07")
    }

    @Test func dailyUploadEncodesCamelCaseAndOmitsMissingValues() throws {
        let body = HealthDailyUploadBody(platform: CollogAPI.healthPlatform, days: [
            HealthDayDTO(
                date: "2026-11-07", sleepMinutes: 370, steps: 3210, restingHeartRate: 64,
                bloodPressureSystolic: 128, bloodPressureDiastolic: 82, bloodGlucoseMgDl: 112.0
            ),
            HealthDayDTO(date: "2026-11-08", steps: 10),
        ])
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
        #expect(json["platform"] as? String == "HEALTHKIT")
        let days = try #require(json["days"] as? [[String: Any]])
        #expect(Set(days[0].keys) == [
            "date", "sleepMinutes", "steps", "restingHeartRate",
            "bloodPressureSystolic", "bloodPressureDiastolic", "bloodGlucoseMgDl",
        ])
        #expect(days[0]["bloodGlucoseMgDl"] as? Double == 112.0)
        #expect(Set(days[1].keys) == ["date", "steps"])
    }

    @Test func parentDailyBecomesLifeRecordForTheWeek() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            #expect(request.url?.path == "/v1/parents/mom/health/daily")
            #expect(request.url?.query == "from=2026-10-09&to=2026-11-07")
            return (200, """
            {"parentId":"mom","connected":true,"platform":"HEALTH_CONNECT","lastSyncedDay":"2026-11-08",
             "days":[
              {"date":"2026-11-01","sleepMinutes":412,"steps":5120,"restingHeartRate":63,
               "bloodPressureSystolic":null,"bloodPressureDiastolic":null,"bloodGlucoseMgDl":null},
              {"date":"2026-11-05","sleepMinutes":370,"steps":3210,"restingHeartRate":null,
               "bloodPressureSystolic":128,"bloodPressureDiastolic":82,"bloodGlucoseMgDl":112.0},
              {"date":"2026-11-07","sleepMinutes":null,"steps":4000,"restingHeartRate":null,
               "bloodPressureSystolic":null,"bloodPressureDiastolic":null,"bloodGlucoseMgDl":null},
              {"date":"2026-11-08","sleepMinutes":300,"steps":100,"restingHeartRate":70,
               "bloodPressureSystolic":null,"bloodPressureDiastolic":null,"bloodGlucoseMgDl":null}
             ],
             "disclaimer":"이 정보는 의료 진단이 아니며 건강 변화 참고용입니다."}
            """)
        }
        let dto = try await fixture.environment.api.parentHealthDaily(parentId: "mom", from: "2026-10-09", to: "2026-11-07")
        let record = LifeRecord(dto: dto, end: day("2026-11-07"), today: day("2026-11-08"))

        #expect(record.connected)
        #expect(record.rangeText == "11/1 ~ 11/7")
        #expect(record.sleep.map(\.label) == ["일", "월", "화", "수", "목", "금", "토"])
        #expect(record.sleep.map(\.value) == [412, nil, nil, nil, 370, nil, nil])
        #expect(record.steps.map(\.value) == [5120, nil, nil, nil, 3210, nil, 4000])
        #expect(record.sleepAverageText == "6시간 31분")
        #expect(record.stepsAverageText == "4,110걸음")
        // 주 끝(11-07) 뒤의 기록(11-08 심박 70)은 쓰지 않는다
        #expect(record.restingHeartRate == LifeRecordLatest(value: "63", unit: "회/분", dateText: "11월 1일"))
        #expect(record.bloodPressure == LifeRecordLatest(value: "128/82", unit: "mmHg", dateText: "11월 5일"))
        #expect(record.bloodGlucose == LifeRecordLatest(value: "112", unit: "mg/dL", dateText: "11월 5일"))
        #expect(record.lastSyncedText == "11월 8일")
        #expect(record.disclaimer == LifeRecord.defaultDisclaimer)

        let thisWeek = LifeRecord(dto: dto, end: day("2026-11-08"), today: day("2026-11-08"))
        #expect(thisWeek.rangeText == "최근 7일")
        #expect(thisWeek.restingHeartRate?.value == "70")
    }

    @Test func notConnectedParentHasNoBars() throws {
        let dto = ParentHealthDailyDTO(
            parentId: "mom", connected: false, platform: nil, lastSyncedDay: nil, days: [], disclaimer: ""
        )
        let record = LifeRecord(dto: dto, end: day("2026-11-08"), today: day("2026-11-08"))
        #expect(!record.connected)
        #expect(record.sleepAverageText == nil)
        #expect(record.restingHeartRate == nil)
        #expect(record.disclaimer == LifeRecord.defaultDisclaimer)
    }

    @Test func connectAuthorizesThenLinksThenUploadsOnlyDaysWithValues() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let source = FakeHealthSource()
        source.records = HealthRecords(stepsByDay: [day("2026-11-07"): 3210, day("2026-11-08"): 120])
        let server = FakeHealthServer(version: version)
        fixture.respond = { [source] request in
            if request.httpMethod == "POST" { #expect(source.authorizationRequests == 1) }
            return try server.respond(request)
        }
        let link = HealthLink(source: source, defaults: fixture.defaults, now: { seoulMorning })

        await link.prepare(using: fixture.environment)
        guard case let .consent(document, _) = link.step else {
            Issue.record("동의 단계가 아님: \(link.step)")
            return
        }
        #expect(document.items.count == 6)
        await link.connect(document, using: fixture.environment)

        #expect(server.links.first?["version"] as? String == version)
        #expect(server.links.first?["platform"] as? String == "HEALTHKIT")
        #expect(server.uploads.count == 1)
        #expect(server.uploads.first?["platform"] as? String == "HEALTHKIT")
        let days = try #require(server.uploads.first?["days"] as? [[String: Any]])
        #expect(days.map { $0["date"] as? String } == ["2026-11-07", "2026-11-08"])
        #expect(link.step == .linked(justConnected: true, lastSyncedDay: "2026-11-08", needsPermission: false))
        #expect(link.rowText(for: "me") == "연결됨")
        #expect(link.revision > 0)

        // 같은 날 앱이 다시 앞으로 와도 또 올리지 않는다
        await link.syncIfDue(using: fixture.environment)
        #expect(server.uploads.count == 1)
    }

    @Test func linkWithoutRecordsStaysLinkedAndRetriesOnNextForeground() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let source = FakeHealthSource()
        let server = FakeHealthServer(version: version)
        fixture.respond = { request in try server.respond(request) }
        let link = HealthLink(source: source, defaults: fixture.defaults, now: { seoulMorning })

        await link.prepare(using: fixture.environment)
        guard case let .consent(document, _) = link.step else {
            Issue.record("동의 단계가 아님: \(link.step)")
            return
        }
        await link.connect(document, using: fixture.environment)
        // 읽기 권한을 허용했는지 알 수 없으니 연결은 유지하고, 기록이 없으면 보내지 않는다
        #expect(server.links.count == 1)
        #expect(server.uploads.isEmpty)
        #expect(link.step == .linked(justConnected: true, lastSyncedDay: nil, needsPermission: false))

        // 나중에 권한을 켜면 그날 다시 앞으로 올 때 보낸다
        source.records = HealthRecords(stepsByDay: [day("2026-11-08"): 500])
        await link.syncIfDue(using: fixture.environment)
        #expect(source.reads == 2)
        #expect(server.uploads.count == 1)
    }

    @Test func disconnectDeletesAndShowsNotLinked() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = FakeHealthServer(version: version, connected: true)
        fixture.respond = { request in try server.respond(request) }
        let link = HealthLink(source: FakeHealthSource(), defaults: fixture.defaults, now: { seoulMorning })
        link.present()
        await link.prepare(using: fixture.environment)
        #expect(link.step == .linked(justConnected: false, lastSyncedDay: "2026-11-07", needsPermission: false))

        await link.disconnect(using: fixture.environment)
        #expect(server.deletes == 1)
        #expect(link.rowText(for: "me") == "연결 안 됨")
        #expect(!link.isPresented)
        #expect(link.shouldShowHint(using: fixture.environment))
    }

    @Test func linkedOnAnotherPhoneAsksForPermissionHere() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let source = FakeHealthSource()
        source.authorizationNeeded = true
        let server = FakeHealthServer(version: version, connected: true)
        fixture.respond = { request in try server.respond(request) }
        let link = HealthLink(source: source, defaults: fixture.defaults, now: { seoulMorning })
        await link.prepare(using: fixture.environment)
        #expect(link.step == .linked(justConnected: false, lastSyncedDay: "2026-11-07", needsPermission: true))

        source.authorizationNeeded = false
        source.records = HealthRecords(stepsByDay: [day("2026-11-08"): 500])
        await link.regrant(using: fixture.environment)
        #expect(source.authorizationRequests == 1)
        #expect(server.uploads.count == 1)
        #expect(link.step == .linked(justConnected: false, lastSyncedDay: "2026-11-08", needsPermission: false))
    }

    /// 실기(11-24): 권한 창을 거쳐 기록을 올린 휴대폰인데도 HealthKit 이 계속 「물어봐야 한다」고 답해
    /// 시트를 열 때마다 「읽기를 허용하지 않아 보내지 못하고 있어요」가 떴다. 이 휴대폰이 기록을 올린 적이 있으면
    /// 읽기가 되는 것이므로 그 안내를 띄우지 않는다.
    @Test func phoneThatUploadedRecordsIsNotToldToAllowReadingAgain() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let source = FakeHealthSource()
        source.authorizationNeeded = true
        source.records = HealthRecords(stepsByDay: [day("2026-11-08"): 500])
        let server = FakeHealthServer(version: version, connected: true)
        fixture.respond = { request in try server.respond(request) }
        let link = HealthLink(source: source, defaults: fixture.defaults, now: { seoulMorning })
        await link.prepare(using: fixture.environment)
        #expect(link.step == .linked(justConnected: false, lastSyncedDay: "2026-11-07", needsPermission: true))

        await link.regrant(using: fixture.environment)
        #expect(server.uploads.count == 1)

        await link.prepare(using: fixture.environment)
        #expect(link.step == .linked(justConnected: false, lastSyncedDay: "2026-11-08", needsPermission: false))

        // 앱을 다시 켜도 같다
        let relaunched = HealthLink(source: source, defaults: fixture.defaults, now: { seoulMorning })
        await relaunched.prepare(using: fixture.environment)
        #expect(relaunched.step == .linked(justConnected: false, lastSyncedDay: "2026-11-08", needsPermission: false))

        // 연결을 끊으면 이 휴대폰의 흔적도 지운다(다른 휴대폰에서 다시 연결하면 여기서는 다시 묻는다)
        await relaunched.disconnect(using: fixture.environment)
        server.connected = true
        server.lastSyncedDay = "2026-11-08"
        await relaunched.prepare(using: fixture.environment)
        #expect(relaunched.step == .linked(justConnected: false, lastSyncedDay: "2026-11-08", needsPermission: true))
    }

    /// 권한 창을 거쳤어도 올린 기록이 없으면(읽기를 허용하지 않았을 수 있다) HealthKit 의 답을 그대로 따른다.
    @Test func phoneWithoutUploadsKeepsFollowingHealthKit() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let source = FakeHealthSource()
        source.authorizationNeeded = true
        let server = FakeHealthServer(version: version, connected: true)
        fixture.respond = { request in try server.respond(request) }
        let link = HealthLink(source: source, defaults: fixture.defaults, now: { seoulMorning })

        await link.regrant(using: fixture.environment)
        #expect(server.uploads.isEmpty)
        await link.prepare(using: fixture.environment)
        #expect(link.step == .linked(justConnected: false, lastSyncedDay: "2026-11-07", needsPermission: true))
    }

    @Test func hintShowsOnceUntilDismissedAndOnlyWhereHealthIsAvailable() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = FakeHealthServer(version: version)
        fixture.respond = { request in try server.respond(request) }
        let link = HealthLink(source: FakeHealthSource(), defaults: fixture.defaults, now: { seoulMorning })
        await link.ensureStatus(using: fixture.environment)
        #expect(link.shouldShowHint(using: fixture.environment))
        link.dismissHint(using: fixture.environment)
        #expect(!link.shouldShowHint(using: fixture.environment))

        let again = HealthLink(source: FakeHealthSource(), defaults: fixture.defaults, now: { seoulMorning })
        await again.ensureStatus(using: fixture.environment)
        #expect(!again.shouldShowHint(using: fixture.environment))

        let noHealth = FakeHealthSource()
        noHealth.isAvailable = false
        let suite = fixture.id + ".unavailable"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let unavailable = HealthLink(source: noHealth, defaults: try #require(UserDefaults(suiteName: suite)), now: { seoulMorning })
        await unavailable.ensureStatus(using: fixture.environment)
        #expect(!unavailable.shouldShowHint(using: fixture.environment))
        #expect(unavailable.rowText(for: "me") == "지원 안 함")
    }

    @Test func guestModeNeverTouchesHealthOrServer() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.environment.settings.isGuestMode = true
        let source = FakeHealthSource()
        source.records = HealthRecords(stepsByDay: [day("2026-11-08"): 500])
        let link = HealthLink(source: source, defaults: fixture.defaults, now: { seoulMorning })

        await link.ensureStatus(using: fixture.environment)
        await link.syncIfDue(using: fixture.environment)
        await link.connect(
            HealthLinkDocument(version: version, title: "", items: []), using: fixture.environment
        )
        #expect(fixture.paths.isEmpty)
        #expect(source.authorizationRequests == 0)
        #expect(source.reads == 0)
        #expect(!link.shouldShowHint(using: fixture.environment))
        #expect(link.rowText(for: "me") == nil)
    }

    private func day(_ string: String) -> Date {
        HealthDailyCalculator.day(from: string)!
    }

    private func linkJSON(connected: Bool, lastSyncedDay: String = "null") -> String {
        FakeHealthServer.linkJSON(version: version, connected: connected, lastSyncedDay: lastSyncedDay)
    }
}

/// 서울 2026-11-08 09:00.
@MainActor private let seoulMorning = HealthDailyCalculator.calendar.date(
    from: DateComponents(year: 2026, month: 11, day: 8, hour: 9)
)!

@MainActor
private final class FakeHealthSource: HealthRecordSource {
    var isAvailable = true
    var authorizationNeeded = false
    var records = HealthRecords()
    private(set) var authorizationRequests = 0
    private(set) var reads = 0

    func needsAuthorization() async -> Bool { authorizationNeeded }

    func requestAuthorization() async throws { authorizationRequests += 1 }

    func read(days: [Date]) async throws -> HealthRecords {
        reads += 1
        return records
    }
}

/// 운영 서버(`app/routes/health.py`)와 같은 응답 모양.
@MainActor
private final class FakeHealthServer {
    let version: String
    var connected: Bool
    var lastSyncedDay: String?
    private(set) var links: [[String: Any]] = []
    private(set) var uploads: [[String: Any]] = []
    private(set) var deletes = 0

    init(version: String, connected: Bool = false) {
        self.version = version
        self.connected = connected
        lastSyncedDay = connected ? "2026-11-07" : nil
    }

    static func linkJSON(version: String, connected: Bool, lastSyncedDay: String) -> String {
        """
        {"connected":\(connected),"consentVersion":\(connected ? "\"\(version)\"" : "null"),
         "connectedAt":\(connected ? "\"2026-11-08T01:02:03.123456+00:00\"" : "null"),
         "document":{"version":"\(version)","title":"건강 앱 연결 (선택)","items":[
          "휴대폰 건강 앱(Health Connect·Apple 건강)에 기록된 수면 시간, 걸음 수, 심박, 혈압, 혈당을 하루 단위로 요약해 콜록 서버로 보냅니다. 분 단위 원본 기록은 보내지 않습니다.",
          "요약은 가족 건강 리포트에 생활 변화를 보여 주는 데만 씁니다.",
          "리포트 공유를 허락한 가족 구성원에게만 보입니다.",
          "연결을 끊거나 탈퇴하면 서버에 저장된 요약을 바로 지웁니다.",
          "동의하지 않아도 콜록의 다른 기능은 그대로 쓸 수 있습니다.",
          "이 정보는 의료 진단이 아니며 건강 변화 참고용입니다."]},
         "lastSyncedDay":\(lastSyncedDay)}
        """
    }

    func respond(_ request: URLRequest) throws -> (Int, String) {
        switch (request.httpMethod ?? "", request.url?.path ?? "") {
        case ("GET", "/v1/health/link"):
            return (200, status)
        case ("POST", "/v1/health/link"):
            links.append(Self.body(request))
            connected = true
            return (200, status)
        case ("DELETE", "/v1/health/link"):
            deletes += 1
            connected = false
            lastSyncedDay = nil
            return (204, "")
        case ("PUT", "/v1/health/daily"):
            let body = Self.body(request)
            uploads.append(body)
            let days = (body["days"] as? [[String: Any]] ?? []).compactMap { $0["date"] as? String }
            lastSyncedDay = ([lastSyncedDay].compactMap { $0 } + days).max()
            return (200, #"{"saved":\#(days.count),"lastSyncedDay":"\#(lastSyncedDay ?? "")"}"#)
        default:
            Issue.record("Unexpected health request \(request.httpMethod ?? "") \(request.url?.path ?? "")")
            throw URLError(.unsupportedURL)
        }
    }

    private var status: String {
        Self.linkJSON(version: version, connected: connected, lastSyncedDay: connected ? lastSyncedDay.map { "\"\($0)\"" } ?? "null" : "null")
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
