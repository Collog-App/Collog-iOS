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
        let recording = try #require(writer.finish())
        let file = try AVAudioFile(
            forReading: recording.url, commonFormat: .pcmFormatInt16, interleaved: true
        )
        let recorded = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 160))
        try file.read(into: recorded)
        #expect(recorded.frameLength == 160)
        let stored = try #require(recorded.int16ChannelData?.pointee)
        #expect((0..<160).allSatisfy { stored[$0] == 0 })
        #expect(recording.durationSeconds == Double(file.length) / 16_000)
    }

    @Test
    func stereoConversionProducesMonoRecordingWithoutChangingInput() throws {
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_800))
        buffer.frameLength = 4_800
        let channels = try #require(buffer.floatChannelData)
        channels[0].update(repeating: 0.25, count: 4_800)
        channels[1].update(repeating: 0.25, count: 4_800)
        let writer = AnalysisPCMWriter()
        defer { writer.discard() }
        try writer.start()
        for _ in 0..<10 { writer.render(pcmBuffer: buffer) }
        let recording = try #require(writer.finish())
        let file = try AVAudioFile(forReading: recording.url)

        #expect(file.processingFormat.channelCount == 1)
        #expect(file.processingFormat.sampleRate == 16_000)
        #expect(file.length > 15_000)
        #expect(file.length <= 16_000)
        #expect(recording.durationSeconds == Double(file.length) / 16_000)
        #expect(channels[0][0] == 0.25)
        #expect(channels[1][4_799] == 0.25)
    }

    @Test
    func finishedRecordingIgnoresLateRenderCallbacks() throws {
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
        writer.render(pcmBuffer: buffer)
        let recording = try #require(writer.finish())
        writer.render(pcmBuffer: buffer)
        let file = try AVAudioFile(forReading: recording.url)

        #expect(file.length == 160)
        #expect(recording.durationSeconds == 0.01)
        #expect(try #require(writer.finish()).levelText == recording.levelText)
    }

    @Test
    func concurrentRenderCallbacksPreserveEveryFrame() throws {
        let writer = AnalysisPCMWriter()
        defer { writer.discard() }
        try writer.start()
        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
            ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160),
                  let samples = buffer.int16ChannelData?.pointee else { return }
            buffer.frameLength = 160
            samples.update(repeating: 1_000, count: 160)
            writer.render(pcmBuffer: buffer)
        }
        let recording = try #require(writer.finish())
        let file = try AVAudioFile(forReading: recording.url)

        #expect(file.length == 3_200)
        #expect(recording.durationSeconds == 0.2)
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
