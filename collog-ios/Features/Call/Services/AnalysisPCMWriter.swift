//
//  AnalysisPCMWriter.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import AVFoundation
import LiveKit

final class AnalysisPCMWriter: NSObject, AudioRenderer, @unchecked Sendable {
    static let sampleRate: Double = 48_000

    private let queue = DispatchQueue(label: "collog.analysis-pcm")
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: AnalysisPCMWriter.sampleRate,
        channels: 1,
        interleaved: true
    )!

    private var file: AVAudioFile?
    private var converter: AVAudioConverter?
    private var sourceFormat: AVAudioFormat?
    private var frameCount: AVAudioFramePosition = 0
    private var peakSample: Int32 = 0
    private var squareSum: Double = 0
    private var sampleCount: Double = 0

    private(set) var url: URL?

    var durationSeconds: Double {
        queue.sync { Double(frameCount) / AnalysisPCMWriter.sampleRate }
    }

    var levelText: String {
        queue.sync {
            let peak = Double(peakSample) / Double(Int16.max)
            let rms = sampleCount > 0 ? (squareSum / sampleCount).squareRoot() : 0
            return String(format: "peak %.1f / rms %.1f dBFS", decibels(peak), decibels(rms))
        }
    }

    func start() throws {
        try queue.sync {
            let directory = FileManager.default.temporaryDirectory
                .appending(path: "collog-analysis", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appending(path: "\(UUID().uuidString).wav")

            file = try AVAudioFile(
                forWriting: target,
                settings: targetFormat.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )
            converter = nil
            sourceFormat = nil
            url = target
            frameCount = 0
            peakSample = 0
            squareSum = 0
            sampleCount = 0
        }
    }

    func render(pcmBuffer: AVAudioPCMBuffer) {
        queue.sync { [weak self] in
            guard let self, let file = self.file else { return }
            do {
                let converted = try self.convert(pcmBuffer)
                try file.write(from: converted)
                self.frameCount += AVAudioFramePosition(converted.frameLength)
                self.accumulateLevels(converted)
            } catch {
                print("[Collog] 분석 PCM 기록 실패: \(error.localizedDescription)")
            }
        }
    }

    func finish() -> URL? {
        queue.sync {
            file = nil
            converter = nil
            sourceFormat = nil
            return url
        }
    }

    func discard() {
        queue.sync {
            file = nil
            converter = nil
            sourceFormat = nil
            if let url {
                try? FileManager.default.removeItem(at: url)
            }
            url = nil
            frameCount = 0
        }
    }

    private func decibels(_ amplitude: Double) -> Double {
        20 * log10(max(amplitude, 1e-9))
    }

    private func accumulateLevels(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.int16ChannelData?.pointee else { return }
        for index in 0..<Int(buffer.frameLength) {
            let value = Int32(channel[index])
            peakSample = max(peakSample, abs(value))
            let normalized = Double(value) / Double(Int16.max)
            squareSum += normalized * normalized
            sampleCount += 1
        }
    }

    private func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        if buffer.format == targetFormat { return buffer }

        if sourceFormat != buffer.format {
            guard let created = AVAudioConverter(from: buffer.format, to: targetFormat) else {
                throw ConversionError.unsupportedFormat
            }
            converter = created
            sourceFormat = buffer.format
        }
        guard let converter else { throw ConversionError.unsupportedFormat }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            throw ConversionError.allocationFailed
        }

        var consumed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if let conversionError { throw conversionError }
        return output
    }

    enum ConversionError: LocalizedError {
        case unsupportedFormat
        case allocationFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: "분석용 PCM 변환 형식을 만들 수 없어요"
            case .allocationFailed: "분석용 PCM 버퍼를 만들 수 없어요"
            }
        }
    }
}
