//
//  CallAudioTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import AVFoundation
import Testing
@testable import collog_ios

@MainActor
struct CallAudioTests {
    @Test
    func mutedLocalAudioIsWrittenAsSilence() throws {
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160))
        buffer.frameLength = 160
        let samples = try #require(buffer.int16ChannelData?.pointee)
        samples.update(repeating: 1_000, count: 160)
        let writer = AnalysisPCMWriter()
        defer { writer.discard() }
        try writer.start()
        writer.setMuted(true)
        writer.render(pcmBuffer: buffer)
        #expect(samples[0] == 1_000)
        let file = try AVAudioFile(
            forReading: #require(writer.finish()), commonFormat: .pcmFormatInt16, interleaved: true
        )
        let recorded = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 160))
        try file.read(into: recorded)
        #expect(recorded.frameLength == 160)
        let stored = try #require(recorded.int16ChannelData?.pointee)
        #expect((0..<160).allSatisfy { stored[$0] == 0 })
    }

    @Test
    func logoutNotifiesCallCleanupBeforeDiscardingCredentials() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        var cleanupSawCredentials = false
        fixture.environment.beforeSignOut = {
            cleanupSawCredentials = fixture.environment.session.isAuthenticated
        }
        fixture.respond = { _ in (200, "{}") }
        await fixture.environment.signOut()
        #expect(cleanupSawCredentials)
        #expect(!fixture.environment.session.isAuthenticated)
        #expect(fixture.paths == ["/v1/auth/logout"])
        fixture.environment.beforeSignOut = nil
    }
}
