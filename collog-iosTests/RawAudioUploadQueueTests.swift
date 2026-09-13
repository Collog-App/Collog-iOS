//
//  RawAudioUploadQueueTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation
import Testing
@testable import collog_ios

@MainActor
struct RawAudioUploadQueueTests {
    @Test
    func transientUploadFailureSurvivesQueueRecreation() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        fixture.uploadError = APIError.transport("offline")
        var queue: RawAudioUploadQueue? = try fixture.makeQueue()
        try fixture.enqueue(on: #require(queue))
        await queue?.resume()
        #expect(queue?.hasPending == true)
        #expect(fixture.requests == 1)
        queue = nil

        fixture.uploadError = nil
        let restored = try fixture.makeQueue()
        await restored.resume()

        #expect(!restored.hasPending)
        #expect(fixture.requests == 1)
        #expect(fixture.uploads == 2)
        #expect(fixture.completions == 1)
    }

    @Test
    func lostCompletionResponseRetriesOnlyCompletion() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        fixture.completeError = APIError.transport("response lost")
        let queue = try fixture.makeQueue()
        try fixture.enqueue(on: queue)
        await queue.resume()
        fixture.completeError = nil
        await queue.resume()

        #expect(!queue.hasPending)
        #expect(fixture.requests == 1)
        #expect(fixture.uploads == 1)
        #expect(fixture.completions == 2)
    }

    @Test
    func differentAccountCannotUploadRetainedAudio() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        let queue = try fixture.makeQueue()
        try fixture.enqueue(on: queue)
        fixture.owner = "other-user"
        await queue.resume()

        #expect(!queue.hasPending)
        #expect(fixture.requests == 0)
        #expect(try fixture.files().isEmpty)
    }

    @Test
    func expiredQueueEntryIsDeletedWithoutNetworkRequest() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        let queue = try fixture.makeQueue()
        try fixture.enqueue(on: queue)
        fixture.date = fixture.date.addingTimeInterval(901)
        await queue.resume()

        #expect(!queue.hasPending)
        #expect(fixture.requests == 0)
        #expect(try fixture.files().isEmpty)
    }

    @Test
    func terminalResponseDeletesAudio() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        fixture.uploadError = APIError.server(status: 410, code: "EXPIRED", message: "expired")
        let queue = try fixture.makeQueue()
        try fixture.enqueue(on: queue)
        await queue.resume()

        #expect(!queue.hasPending)
        #expect(try fixture.files().isEmpty)
    }

    @Test
    func discardDuringUploadPreventsCompletion() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        let queue = try fixture.makeQueue()
        fixture.onUpload = { queue.discardAll() }
        try fixture.enqueue(on: queue)
        await queue.resume()

        #expect(fixture.completions == 0)
        #expect(!queue.hasPending)
        #expect(try fixture.files().isEmpty)
    }

    @Test
    func accountChangeDuringUploadPreventsCompletion() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        let queue = try fixture.makeQueue()
        fixture.onUpload = { fixture.owner = "other-user" }
        try fixture.enqueue(on: queue)
        await queue.resume()

        #expect(fixture.completions == 0)
        #expect(!queue.hasPending)
        #expect(try fixture.files().isEmpty)
    }

    @Test
    func signOutImmediatelyPurgesPendingAudio() throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        let queue = try fixture.makeQueue()
        try fixture.enqueue(on: queue)
        fixture.owner = nil
        queue.discardInvalidOwners()

        #expect(!queue.hasPending)
        #expect(try fixture.files().isEmpty)
    }

    @Test
    func discardCallDuringUploadCannotRestoreJob() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        let queue = try fixture.makeQueue()
        fixture.onUpload = { queue.discard(callId: "call") }
        try fixture.enqueue(on: queue)
        await queue.resume()

        #expect(fixture.completions == 0)
        #expect(!queue.hasPending)
        #expect(try fixture.files().isEmpty)
    }

    @Test
    func pauseDuringUploadPreservesJobWithoutCompletingIt() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        let queue = try fixture.makeQueue()
        fixture.onUpload = { queue.pause() }
        try fixture.enqueue(on: queue)
        await queue.resume()

        #expect(fixture.completions == 0)
        #expect(queue.hasPending)

        fixture.onUpload = nil
        await queue.resume()
        #expect(fixture.completions == 1)
        #expect(!queue.hasPending)
    }

    @Test
    func revokedPermissionPreventsCachedUploadAndPurgesAudio() async throws {
        let fixture = try UploadFixture()
        defer { fixture.cleanup() }
        fixture.uploadError = APIError.transport("offline")
        let queue = try fixture.makeQueue()
        try fixture.enqueue(on: queue)
        await queue.resume()
        #expect(queue.hasPending)

        fixture.uploadError = nil
        fixture.permissionError = APIError.server(status: 403, code: "CONSENT_REQUIRED", message: "denied")
        await queue.resume()

        #expect(!queue.hasPending)
        #expect(fixture.uploads == 1)
        #expect(fixture.completions == 0)
        #expect(try fixture.files().isEmpty)
    }
}

@MainActor
private final class UploadFixture {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    var owner: String? = "parent"
    var date = Date()
    var requests = 0
    var uploads = 0
    var completions = 0
    var uploadError: Error?
    var completeError: Error?
    var permissionError: Error?
    var onUpload: (() -> Void)?

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func makeQueue() throws -> RawAudioUploadQueue {
        try RawAudioUploadQueue(
            directory: directory.appending(path: "queue"), currentOwner: { self.owner },
            now: { self.date }, retryDelay: .seconds(3_600),
            validatePermission: { _ in
                if let error = self.permissionError { throw error }
            },
            requestUpload: { _, _, _ in
                self.requests += 1
                return RawAudioUpload(uploadUrl: "https://storage.example/audio", assetId: "asset", expiresIn: 900)
            },
            upload: { _, _ in
                self.uploads += 1
                self.onUpload?()
                if let error = self.uploadError { throw error }
            },
            complete: { _, _ in
                self.completions += 1
                if let error = self.completeError { throw error }
            }
        )
    }

    func enqueue(on queue: RawAudioUploadQueue) throws {
        let file = directory.appending(path: UUID().uuidString)
        try Data("audio".utf8).write(to: file)
        try queue.enqueue(fileURL: file, callId: "call", ownerID: "parent", durationSec: 30, sampleRate: 16_000)
    }

    func files() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory.appending(path: "queue"), includingPropertiesForKeys: nil
        )
    }

    func cleanup() { try? FileManager.default.removeItem(at: directory) }
}
