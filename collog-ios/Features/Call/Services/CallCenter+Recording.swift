//
//  CallCenter+Recording.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import LiveKit
import UIKit

extension CallCenter {
    func makeUploadQueue() -> RawAudioUploadQueue? {
        do {
            return try RawAudioUploadQueue(
                currentOwner: { [weak self] in self?.environment.session.user?.id },
                validatePermission: { [weak self] callId in
                    guard let self else { throw CancellationError() }
                    let status = try await environment.api.callStatus(callId: callId)
                    guard status.recordingEnabled == true else { throw APIError.unauthenticated }
                },
                requestUpload: { [weak self] callId, duration, sampleRate in
                    guard let self else { throw CancellationError() }
                    return try await environment.api.rawAudioUploadURL(
                        callId: callId, durationSec: duration, sampleRate: sampleRate
                    )
                },
                upload: { [weak self] file, url in
                    guard let self else { throw CancellationError() }
                    try await environment.api.uploadRawAudio(fileURL: file, to: url)
                },
                complete: { [weak self] callId, assetId in
                    guard let self else { throw CancellationError() }
                    try await environment.api.completeRawAudio(callId: callId, assetId: assetId)
                }
            )
        } catch {
            log("음성 업로드 대기열을 준비하지 못했어요")
            return nil
        }
    }

    func resumePendingUploads() {
        uploads?.discardInvalidOwners()
        guard let uploads, uploads.hasPending, uploadBackgroundTask == .invalid else { return }
        uploadBackgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor [weak self] in
                self?.uploads?.pause()
                self?.endUploadBackgroundTask()
            }
        }
        Task {
            await uploads.resume()
            endUploadBackgroundTask()
        }
    }

    private func endUploadBackgroundTask() {
        guard uploadBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(uploadBackgroundTask)
        uploadBackgroundTask = .invalid
    }

    func attachAnalysisWriter(to publication: LocalTrackPublication?) {
        guard analysisWriter == nil, let call = activeCall,
              CallSafety.canRecord(
                enabled: call.recordingEnabled, rawRequired: rawCaptureRequired,
                accepted: serverAccepted, phase: call.phase
              ) else { return }
        let resolved = publication?.track ?? room.localParticipant.audioTracks.first?.track
        guard let track = resolved as? LocalAudioTrack else {
            log("분석 PCM 실패: local audio track을 찾지 못했다")
            return
        }

        let writer = AnalysisPCMWriter()
        do {
            try writer.start()
        } catch {
            writer.discard()
            log("분석 PCM 시작 실패: \(error.localizedDescription)")
            return
        }
        track.add(audioRenderer: writer)
        writer.setMuted(call.isMuted)
        analysisWriter = writer
        analysisTrack = track
        log("분석 PCM 기록 시작")
    }

    func finishAnalysisRecording(callId: String) {
        guard let writer = analysisWriter else { return }
        analysisWriter = nil
        analysisTrack?.remove(audioRenderer: writer)
        analysisTrack = nil

        let duration = writer.durationSeconds
        log("분석 PCM \(writer.levelText)")

        guard let fileURL = writer.finish(), duration > 0 else {
            writer.discard()
            log("분석 PCM 없음")
            return
        }

        do {
            guard let ownerId = callOwnerId, ownerId == environment.session.user?.id,
                  let uploads, activeCall?.recordingEnabled == true else {
                writer.discard()
                return
            }
            try uploads.enqueue(
                fileURL: fileURL, callId: callId, ownerID: ownerId,
                durationSec: duration, sampleRate: Int(AnalysisPCMWriter.sampleRate)
            )
            resumePendingUploads()
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            log("분석 음성을 업로드 대기열에 저장하지 못했어요")
        }
    }

    func discardAnalysisRecording() {
        if let writer = analysisWriter { analysisTrack?.remove(audioRenderer: writer) }
        analysisWriter?.discard()
        analysisWriter = nil
        analysisTrack = nil
        rawCaptureRequired = false
        if let callId = activeCall?.id { uploads?.discard(callId: callId) }
    }

    func applyRecordingStatus(_ enabled: Bool, message: String?) {
        let shouldStop = !enabled && !recordingStopped
        if !enabled { recordingStopped = true }
        activeCall?.recordingEnabled = enabled && !recordingStopped
        if !enabled {
            if shouldStop { discardAnalysisRecording() }
            activeCall?.notice = message ?? "이번 통화는 녹음과 분석 없이 진행해요."
        }
    }
}
