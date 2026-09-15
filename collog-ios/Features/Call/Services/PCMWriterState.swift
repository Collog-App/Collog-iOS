//
//  PCMWriterState.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/14/26.
//

import AVFoundation
import Synchronization

nonisolated struct PCMWriterState {
    let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
    )!
    var file: AVAudioFile?
    var converter: AVAudioConverter?
    var sourceFormat: AVAudioFormat?
    var url: URL?
    var frameCount: AVAudioFramePosition = 0
    var peakSample: Int32 = 0
    var squareSum: Double = 0
    var sampleCount: Double = 0
    var muted = false

    var levelText: String {
        let peak = Double(peakSample) / Double(Int16.max)
        let rms = sampleCount > 0 ? (squareSum / sampleCount).squareRoot() : 0
        return String(
            format: "peak %.1f / rms %.1f dBFS",
            20 * log10(max(peak, 1e-9)), 20 * log10(max(rms, 1e-9))
        )
    }

    mutating func accumulateLevels(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.int16ChannelData?.pointee else { return }
        for index in 0..<Int(buffer.frameLength) {
            let value = Int32(channel[index])
            peakSample = max(peakSample, abs(value))
            let normalized = Double(value) / Double(Int16.max)
            squareSum += normalized * normalized
            sampleCount += 1
        }
    }

    mutating func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
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

        let snapshot = try InputSnapshot(buffer)
        let input = InputState()
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            let shouldSupply = input.flags.withLock { state in
                guard !state.consumed else { return false }
                state.consumed = true
                return true
            }
            guard shouldSupply else {
                status.pointee = .noDataNow
                return nil
            }
            do {
                let buffer = try snapshot.makeBuffer()
                status.pointee = .haveData
                return buffer
            } catch {
                input.flags.withLock { $0.failed = true }
                status.pointee = .noDataNow
                return nil
            }
        }
        if let conversionError { throw conversionError }
        if input.flags.withLock({ $0.failed }) { throw ConversionError.allocationFailed }
        return output
    }

    nonisolated private final class InputState: Sendable {
        let flags = Mutex((consumed: false, failed: false))
    }

    private struct InputSnapshot: Sendable {
        let commonFormat: UInt
        let sampleRate: Double
        let channelCount: UInt32
        let interleaved: Bool
        let frameLength: UInt32
        let planes: [Data]

        init(_ source: AVAudioPCMBuffer) throws {
            commonFormat = source.format.commonFormat.rawValue
            sampleRate = source.format.sampleRate
            channelCount = source.format.channelCount
            interleaved = source.format.isInterleaved
            frameLength = source.frameLength
            planes = try UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList).map { buffer in
                guard let bytes = buffer.mData else { throw ConversionError.allocationFailed }
                return Data(bytes: bytes, count: Int(buffer.mDataByteSize))
            }
        }

        func makeBuffer() throws -> AVAudioPCMBuffer {
            guard let commonFormat = AVAudioCommonFormat(rawValue: commonFormat), let format = AVAudioFormat(
                commonFormat: commonFormat, sampleRate: sampleRate, channels: channelCount, interleaved: interleaved
            ), let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frameLength, 1)) else {
                throw ConversionError.allocationFailed
            }
            copy.frameLength = frameLength
            let buffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            guard buffers.count == planes.count else { throw ConversionError.allocationFailed }
            for index in buffers.indices {
                guard let destination = buffers[index].mData,
                      planes[index].count <= Int(buffers[index].mDataByteSize) else {
                    throw ConversionError.allocationFailed
                }
                planes[index].copyBytes(to: destination.assumingMemoryBound(to: UInt8.self), count: planes[index].count)
            }
            return copy
        }
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
