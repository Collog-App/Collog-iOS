//
//  AnalysisPCMWriter.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import AVFoundation
import LiveKit
import Synchronization

nonisolated final class AnalysisPCMWriter: NSObject, AudioRenderer {
    nonisolated struct Recording: Sendable {
        let url: URL
        let durationSeconds: Double
        let levelText: String
    }

    static let sampleRate: Double = 16_000
    private let state = Mutex(PCMWriterState())

    static func purgeAbandonedRecordings() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        for file in files where file.pathExtension == "wav" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static var directory: URL {
        FileManager.default.temporaryDirectory.appending(path: "collog-analysis", directoryHint: .isDirectory)
    }

    func start() throws {
        try state.withLock { state in
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            let target = Self.directory.appending(path: "\(UUID().uuidString).wav")
            state.file = try AVAudioFile(
                forWriting: target, settings: state.targetFormat.settings,
                commonFormat: .pcmFormatInt16, interleaved: true
            )
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: target.path
            )
            state.converter = nil
            state.sourceFormat = nil
            state.url = target
            state.frameCount = 0
            state.peakSample = 0
            state.squareSum = 0
            state.sampleCount = 0
        }
    }

    func render(pcmBuffer: AVAudioPCMBuffer) {
        state.withLock { state in
            guard let file = state.file else { return }
            do {
                var converted = try state.convert(pcmBuffer)
                if state.muted {
                    guard let silence = AVAudioPCMBuffer(
                        pcmFormat: state.targetFormat, frameCapacity: max(converted.frameLength, 1)
                    ), let samples = silence.int16ChannelData?.pointee else {
                        throw PCMWriterState.ConversionError.allocationFailed
                    }
                    silence.frameLength = converted.frameLength
                    samples.update(repeating: 0, count: Int(silence.frameLength))
                    converted = silence
                }
                try file.write(from: converted)
                state.frameCount += AVAudioFramePosition(converted.frameLength)
                state.accumulateLevels(converted)
            } catch {
                print("[Collog] 분석 PCM 기록 실패: \(error.localizedDescription)")
            }
        }
    }

    func finish() -> Recording? {
        state.withLock { state in
            state.file = nil
            state.converter = nil
            state.sourceFormat = nil
            guard let url = state.url else { return nil }
            return Recording(
                url: url, durationSeconds: Double(state.frameCount) / Self.sampleRate, levelText: state.levelText
            )
        }
    }

    func setMuted(_ muted: Bool) {
        state.withLock { $0.muted = muted }
    }

    func discard() {
        state.withLock { state in
            state.file = nil
            state.converter = nil
            state.sourceFormat = nil
            if let url = state.url { try? FileManager.default.removeItem(at: url) }
            state.url = nil
            state.frameCount = 0
        }
    }
}
