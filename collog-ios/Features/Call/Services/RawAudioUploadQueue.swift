//
//  RawAudioUploadQueue.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation

@MainActor
final class RawAudioUploadQueue {
    private struct Upload: Codable {
        let url: String
        let assetID: String
        let expiresAt: Date
    }

    private struct Job: Codable {
        let id: UUID
        let callID: String
        let ownerID: String
        let createdAt: Date
        let duration: Double
        let sampleRate: Int
        var upload: Upload?
        var uploaded = false
    }

    private let directory: URL
    private let owner: () -> String?
    private let now: () -> Date
    private let request: (String, Double, Int) async throws -> RawAudioUpload
    private let upload: (URL, String) async throws -> Void
    private let complete: (String, String) async throws -> Void
    private let validatePermission: (String) async throws -> Void
    private let retryDelay: Duration
    private var worker: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var generation = UUID()

    var hasPending: Bool { (try? jobs().isEmpty) == false }

    init(
        directory: URL? = nil,
        currentOwner: @escaping () -> String?,
        now: @escaping () -> Date = Date.init,
        retryDelay: Duration = .seconds(10),
        validatePermission: @escaping (String) async throws -> Void = { _ in },
        requestUpload: @escaping (String, Double, Int) async throws -> RawAudioUpload,
        upload: @escaping (URL, String) async throws -> Void,
        complete: @escaping (String, String) async throws -> Void
    ) throws {
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appending(path: "PendingCallAudio", directoryHint: .isDirectory)
        owner = currentOwner
        self.now = now
        self.retryDelay = retryDelay
        self.validatePermission = validatePermission
        request = requestUpload
        self.upload = upload
        self.complete = complete
        try FileManager.default.createDirectory(
            at: self.directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        var location = self.directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try location.setResourceValues(values)
        try removeExpiredFiles()
    }

    func enqueue(
        fileURL: URL, callId: String, ownerID: String, durationSec: Double, sampleRate: Int
    ) throws {
        guard owner() == ownerID, durationSec.isFinite, durationSec > 0, sampleRate > 0 else {
            throw APIError.unauthenticated
        }
        let job = Job(
            id: UUID(), callID: callId, ownerID: ownerID, createdAt: now(),
            duration: durationSec, sampleRate: sampleRate
        )
        let destination = audioURL(job)
        try FileManager.default.copyItem(at: fileURL, to: destination)
        do {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
                 .posixPermissions: 0o600], ofItemAtPath: destination.path
            )
            try save(job)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    func resume() async {
        if let worker {
            await worker.value
            return
        }
        retry?.cancel()
        retry = nil
        let expected = generation
        let task = Task { await process(expected: expected) }
        worker = task
        await task.value
        guard generation == expected else { return }
        worker = nil
        if hasPending {
            retry = Task { [weak self, retryDelay] in
                do { try await Task.sleep(for: retryDelay) } catch { return }
                await self?.resume()
            }
        }
    }

    func pause() {
        generation = UUID()
        worker?.cancel()
        worker = nil
        retry?.cancel()
        retry = nil
    }

    func discard(callId: String) {
        let removed = ((try? jobs()) ?? []).filter { $0.callID == callId }
        guard !removed.isEmpty else { return }
        pause()
        for job in removed { remove(job) }
        if hasPending {
            retry = Task { [weak self] in await self?.resume() }
        }
    }

    func discardAll() {
        pause()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    func discardInvalidOwners() {
        guard let current = owner() else {
            discardAll()
            return
        }
        for job in (try? jobs()) ?? [] where job.ownerID != current { remove(job) }
    }

    private func process(expected: UUID) async {
        try? removeExpiredFiles()
        guard let pending = try? jobs() else { return }
        for var job in pending {
            guard generation == expected, !Task.isCancelled else { return }
            guard owner() == job.ownerID, now().timeIntervalSince(job.createdAt) < 900 else {
                remove(job)
                continue
            }
            do {
                try await validatePermission(job.callID)
                guard valid(job, expected: expected) else { return }
                let urlExpired = job.upload.map { $0.expiresAt <= now() } ?? true
                if job.upload == nil || (!job.uploaded && urlExpired) {
                    let response = try await request(job.callID, job.duration, job.sampleRate)
                    guard valid(job, expected: expected) else { return }
                    job.upload = Upload(
                        url: response.uploadUrl, assetID: response.assetId,
                        expiresAt: now().addingTimeInterval(Double(max(0, response.expiresIn - 5)))
                    )
                    try save(job)
                    try await validatePermission(job.callID)
                    guard valid(job, expected: expected) else { return }
                }
                guard let target = job.upload else { continue }
                if !job.uploaded {
                    try await upload(audioURL(job), target.url)
                    guard valid(job, expected: expected) else { return }
                    job.uploaded = true
                    try save(job)
                    try await validatePermission(job.callID)
                    guard valid(job, expected: expected) else { return }
                }
                try await complete(job.callID, target.assetID)
                guard valid(job, expected: expected) else { return }
                remove(job)
            } catch {
                guard generation == expected, !Task.isCancelled else { return }
                if owner() != job.ownerID || !Self.canRetry(error) { remove(job) }
            }
        }
    }

    private func valid(_ job: Job, expected: UUID) -> Bool {
        guard generation == expected, !Task.isCancelled else { return false }
        guard owner() == job.ownerID, now().timeIntervalSince(job.createdAt) < 900 else {
            remove(job)
            return false
        }
        return true
    }

    private static func canRetry(_ error: Error) -> Bool {
        switch error {
        case APIError.unauthenticated: false
        case let APIError.server(status, _, _): status == 408 || status == 429 || status >= 500
        default: true
        }
    }

    private func jobs() throws -> [Job] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Job.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func save(_ job: Job) throws {
        try JSONEncoder().encode(job).write(
            to: directory.appending(path: "\(job.id).json"),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    private func audioURL(_ job: Job) -> URL {
        directory.appending(path: "\(job.id).wav")
    }

    private func remove(_ job: Job) {
        try? FileManager.default.removeItem(at: audioURL(job))
        try? FileManager.default.removeItem(at: directory.appending(path: "\(job.id).json"))
    }

    private func removeExpiredFiles() throws {
        for job in try jobs() where now().timeIntervalSince(job.createdAt) >= 900 { remove(job) }
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        )
        for file in files {
            let modified = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if let modified, now().timeIntervalSince(modified) >= 86_400 {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
