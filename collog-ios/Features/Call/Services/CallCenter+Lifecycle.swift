//
//  CallCenter+Lifecycle.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import AVFAudio
import CallKit
import LiveKit

extension CallCenter {
    func sessionDidChange() {
        if let owner = callOwnerId, owner != environment.session.user?.id {
            if let call = activeCall {
                provider.reportCall(with: call.uuid, endedAt: nil, reason: .failed)
            }
            discardAnalysisRecording()
            teardown()
        }
        uploads?.discardInvalidOwners()
        resumePendingUploads()
    }

    func prepareSignOut() async {
        let call = activeCall
        let acceptedHere = call.map { answeredCallIds.contains($0.id) } ?? false
        let api = environment.api
        if let call { provider.reportCall(with: call.uuid, endedAt: nil, reason: .remoteEnded) }
        discardAnalysisRecording()
        uploads?.discardAll()
        teardown()
        guard let call else { return }
        do {
            if call.direction == .incoming, !acceptedHere {
                try await api.declineCall(callId: call.id)
            } else {
                try await api.endCall(callId: call.id)
            }
        } catch { log("로그아웃 전 통화 종료 요청을 보내지 못했어요") }
    }

    func startOutgoingCall(calleeId: String, name: String, questions _: [String]) {
        guard activeCall == nil, pendingOutgoing == nil,
              let userId = environment.session.user?.id, environment.session.isAuthenticated else { return }
        callOwnerId = userId
        let uuid = UUID()
        pendingOutgoing = PendingOutgoing(
            uuid: uuid,
            calleeId: calleeId,
            name: name
        )
        Task {
            let permitted = await AVAudioApplication.requestRecordPermission()
            guard pendingOutgoing?.uuid == uuid else { return }
            guard permitted else {
                failCall(uuid: uuid, message: "통화하려면 iPhone 설정에서 마이크를 허용해주세요", microphone: true)
                return
            }
            let action = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: name))
            action.contactIdentifier = name
            do {
                try prepareCallAudio()
                try await callController.request(CXTransaction(action: action))
            } catch {
                failCall(uuid: uuid, message: error.localizedDescription)
            }
        }
    }

    func endActiveCall() {
        guard let uuid = activeCall?.uuid ?? pendingOutgoing?.uuid else { return }
        callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { [weak self] error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                self?.failCall(uuid: uuid, message: error.localizedDescription)
            }
        }
    }

    func teardown() {
        questionSpeaker.stop()
        serverQuestions = []
        spokenCallId = nil
        statusTask?.cancel()
        statusTask = nil
        if let callId = activeCall?.id {
            answeredCallIds.remove(callId)
            answeringCallIds.remove(callId)
            finishAnalysisRecording(callId: callId)
        } else {
            analysisTrack = nil
            analysisWriter?.discard()
            analysisWriter = nil
        }
        rawCaptureRequired = false
        serverAccepted = false
        statusUnavailable = false
        recordingStopped = false
        callOwnerId = nil
        microphoneTask?.cancel()
        microphoneTask = nil
        muteTask?.cancel()
        muteTask = nil
        isAudioSessionActive = false
        isMediaConnected = false
        didPublishMicrophone = false
        microphoneReady = false
        pendingCapture = nil
        pendingOutgoing = nil
        activeCall = nil
        let previousRoom = room
        previousRoom.remove(delegate: self)
        room = Room()
        room.add(delegate: self)
        setEngine(.none)
        Task { await previousRoom.disconnect() }
    }

    func failCall(uuid: UUID, message: String, microphone: Bool = false) {
        guard activeCall?.uuid == uuid || pendingOutgoing?.uuid == uuid else { return }
        let call = activeCall
        let acceptedHere = call.map { answeredCallIds.contains($0.id) } ?? false
        callError = message
        needsMicrophoneSettings = microphone
        provider.reportCall(with: uuid, endedAt: nil, reason: .failed)
        teardown()
        if let call {
            Task {
                do {
                    if call.direction == .incoming, !acceptedHere {
                        try await environment.api.declineCall(callId: call.id)
                    } else {
                        try await environment.api.endCall(callId: call.id)
                    }
                } catch { log("종료 보고 실패: \(error.localizedDescription)") }
            }
        }
    }

    func monitorCall(_ callId: String) {
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            var lastSuccess = Date()
            while !Task.isCancelled {
                guard let self, activeCall?.id == callId else { return }
                do {
                    let status = try await environment.api.callStatus(callId: callId)
                    guard !Task.isCancelled, activeCall?.id == callId else { return }
                    lastSuccess = Date()
                    if statusUnavailable, activeCall?.recordingEnabled == true { activeCall?.notice = nil }
                    statusUnavailable = false
                    if status.hasEnded {
                        if status.recordingEnabled == false {
                            applyRecordingStatus(false, message: status.recordingDisabledMessage)
                        }
                        finishRemoteCall()
                        return
                    }
                    if let recordingEnabled = status.recordingEnabled {
                        applyRecordingStatus(recordingEnabled, message: status.recordingDisabledMessage)
                    }
                    if status.state == "ACTIVE" {
                        if activeCall?.direction == .incoming, !answeredCallIds.contains(callId) {
                            if !answeringCallIds.contains(callId) {
                                finishRemoteCall(reason: .answeredElsewhere)
                                return
                            }
                        } else {
                            serverAccepted = true
                            markCallActive()
                        }
                    }
                } catch {
                    guard !Task.isCancelled, activeCall?.id == callId else { return }
                    if CallSafety.isPermanentStatusError(error) {
                        discardAnalysisRecording()
                        finishRemoteCall(reason: .failed)
                        return
                    }
                    activeCall?.notice = "통화 상태를 확인하고 있어요. 인터넷 상태를 확인해 주세요."
                    statusUnavailable = true
                    if Date().timeIntervalSince(lastSuccess) >= 30 {
                        if let call = activeCall {
                            failCall(uuid: call.uuid, message: "통화 상태를 확인할 수 없어 통화를 종료했어요.")
                        }
                        return
                    }
                }
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
            }
        }
    }

    func finishRemoteCall(reason: CXCallEndedReason = .remoteEnded) {
        guard let call = activeCall else { return }
        provider.reportCall(with: call.uuid, endedAt: nil, reason: reason)
        teardown()
    }

    func handleMediaError(_ error: Error, uuid: UUID) {
        guard activeCall?.uuid == uuid else { return }
        if (error as? LiveKitError)?.type == .roomDeleted {
            log("서버 통화 종료")
            finishRemoteCall()
        } else {
            failCall(uuid: uuid, message: error.localizedDescription)
        }
    }
}
