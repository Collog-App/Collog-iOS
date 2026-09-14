//
//  CallCenter+CallKit.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import AVFAudio
import CallKit
import LiveKit

extension CallCenter: @MainActor CXProviderDelegate {
    private func response(for action: CXAction) -> CallActionResponse {
        let id = action.uuid
        let response = CallActionResponse(action: action) { [weak self] in
            self?.actionResponses.removeValue(forKey: id)
        }
        actionResponses[id] = response
        return response
    }

    func providerDidReset(_: CXProvider) {
        for response in Array(actionResponses.values) { response.invalidate() }
        if let uuid = activeCall?.uuid ?? pendingOutgoing?.uuid {
            failCall(uuid: uuid, message: "통화 서비스가 중단되었어요. 다시 시도해주세요")
        } else {
            teardown()
        }
    }

    func provider(_: CXProvider, timedOutPerforming action: CXAction) {
        actionResponses[action.uuid]?.invalidate()
        guard let action = action as? CXCallAction else { return }
        failCall(uuid: action.callUUID, message: "통화 요청 시간이 초과되었어요. 다시 시도해주세요")
    }

    func provider(_: CXProvider, perform action: CXStartCallAction) {
        let response = response(for: action)
        guard let pending = pendingOutgoing, pending.uuid == action.callUUID else {
            response.fail()
            return
        }
        Task {
            var actionFulfilled = false
            do {
                let created = try await environment.api.createCall(calleeId: pending.calleeId)
                guard pendingOutgoing?.uuid == pending.uuid else {
                    try? await environment.api.endCall(callId: created.callId)
                    response.fail()
                    return
                }
                activeCall = ActiveCall(
                    id: created.callId,
                    uuid: pending.uuid,
                    direction: .outgoing,
                    peerId: pending.calleeId,
                    peerName: pending.name,
                    phase: .connecting,
                    questions: created.questions.map(\.text),
                    notice: created.recordingEnabled ? nil : created.recordingDisabledMessage,
                    recordingEnabled: created.recordingEnabled
                )
                serverQuestions = created.questions
                rawCaptureRequired = created.rawCaptureRequired ?? false
                response.fulfill()
                actionFulfilled = true
                provider.reportOutgoingCall(with: pending.uuid, startedConnectingAt: nil)
                let update = CXCallUpdate()
                update.localizedCallerName = pending.name
                update.supportsHolding = false
                update.supportsGrouping = false
                update.supportsUngrouping = false
                update.supportsDTMF = false
                provider.reportCall(with: pending.uuid, updated: update)
                monitorCall(created.callId)

                try await connectMedia(
                    callId: created.callId,
                    url: created.livekitUrl,
                    token: created.accessToken,
                    roomName: created.roomName,
                    constraints: created.audioConstraints
                )
                if activeCall?.id == created.callId, activeCall?.phase != .active {
                    activeCall?.phase = .ringing
                    speakQuestionsIfReady()
                }
            } catch {
                if !actionFulfilled { response.fail() }
                if activeCall?.uuid == pending.uuid {
                    handleMediaError(error, uuid: pending.uuid)
                } else {
                    failCall(uuid: pending.uuid, message: error.localizedDescription)
                }
            }
        }
    }

    func provider(_: CXProvider, perform action: CXAnswerCallAction) {
        let response = response(for: action)
        guard let call = activeCall, call.uuid == action.callUUID, call.direction == .incoming else {
            response.fail()
            return
        }
        guard !answeredCallIds.contains(call.id), !answeringCallIds.contains(call.id) else {
            response.fail()
            return
        }
        answeringCallIds.insert(call.id)
        incomingAnswerRequested = true
        incomingAnswerError = nil
        Task {
            var actionFulfilled = false
            let requestId = UUID().uuidString
            defer { answeringCallIds.remove(call.id) }
            do {
                let permitted = await AVAudioApplication.requestRecordPermission()
                guard activeCall?.uuid == call.uuid else {
                    response.fail()
                    return
                }
                guard permitted else {
                    response.fail()
                    failCall(
                        uuid: call.uuid,
                        message: "통화하려면 iPhone 설정에서 마이크를 허용해주세요",
                        microphone: true
                    )
                    return
                }
                activeCall?.phase = .connecting
                let accepted = try await acceptCallWithRetry(callId: call.id, requestId: requestId)
                guard activeCall?.id == call.id else {
                    try? await environment.api.endCall(callId: call.id)
                    response.fail()
                    return
                }
                answeredCallIds.insert(call.id)
                serverAccepted = true
                rawCaptureRequired = accepted.rawCaptureRequired
                applyRecordingStatus(
                    accepted.recordingEnabled ?? accepted.rawCaptureRequired,
                    message: nil
                )
                response.fulfill()
                actionFulfilled = true
                try await connectMedia(
                    callId: call.id,
                    url: accepted.livekitUrl,
                    token: accepted.accessToken,
                    roomName: accepted.roomName,
                    constraints: accepted.audioConstraints
                )
                guard activeCall?.id == call.id else {
                    return
                }
                markCallActive()
            } catch {
                if !actionFulfilled { response.fail() }
                if case let APIError.server(status, _, _) = error, [409, 410].contains(status) {
                    guard activeCall?.id == call.id else { return }
                    finishRemoteCall(reason: status == 409 ? .answeredElsewhere : .unanswered)
                    return
                }
                handleMediaError(error, uuid: call.uuid)
            }
        }
    }

    private func acceptCallWithRetry(callId: String, requestId: String) async throws -> CallAccepted {
        for attempt in 0..<3 {
            do {
                return try await environment.api.acceptCall(callId: callId, requestId: requestId)
            } catch {
                guard attempt < 2, CallSafety.canRetry(error), activeCall?.id == callId else { throw error }
                try await Task.sleep(for: .seconds(1))
            }
        }
        throw CancellationError()
    }

    func provider(_: CXProvider, perform action: CXSetMutedCallAction) {
        let response = response(for: action)
        let isMuted = action.isMuted
        guard let call = activeCall, call.uuid == action.callUUID else {
            response.fail()
            return
        }
        activeCall?.isMuted = isMuted
        analysisWriter?.setMuted(isMuted)
        let targetRoom = room
        let previousMute = muteTask
        muteTask = Task {
            await previousMute?.value
            await microphoneTask?.value
            guard room === targetRoom, activeCall?.uuid == call.uuid else {
                response.fail()
                return
            }
            do {
                if isMediaConnected || didPublishMicrophone {
                    let publication = try await targetRoom.localParticipant.setMicrophone(enabled: !isMuted)
                    guard room === targetRoom, activeCall?.uuid == call.uuid else {
                        response.fail()
                        return
                    }
                    attachAnalysisWriter(to: publication)
                }
                response.fulfill()
            } catch {
                response.fail()
                failCall(uuid: call.uuid, message: "마이크 상태를 바꾸지 못해 통화를 종료했어요.")
            }
        }
    }

    func provider(_: CXProvider, perform action: CXEndCallAction) {
        let response = response(for: action)
        guard activeCall?.uuid == action.callUUID || pendingOutgoing?.uuid == action.callUUID else {
            response.fulfill()
            return
        }
        let call = activeCall
        let answered = call.map { $0.direction == .outgoing || answeredCallIds.contains($0.id) } ?? false
        response.fulfill()
        teardown()
        guard let call else { return }

        answeredCallIds.remove(call.id)
        Task {
            do {
                if answered {
                    try await environment.api.endCall(callId: call.id)
                } else {
                    try await environment.api.declineCall(callId: call.id)
                }
            } catch {
                log("종료 보고 실패: \(error.localizedDescription)")
            }
        }
    }

    func provider(_: CXProvider, didActivate session: AVAudioSession) {
        guard hasCallInProgress else { return }
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers])
            guard setEngine(.default) else {
                if let call = activeCall {
                    failCall(uuid: call.uuid, message: "통화 오디오를 시작할 수 없어요. 다시 시도해주세요")
                }
                return
            }
            isAudioSessionActive = true
            analysisWriter?.setMuted(activeCall?.isMuted ?? true)
            let outputs = session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
            log("CallKit 오디오 활성화, 출력=\(outputs)")
            publishMicrophoneIfReady()
            markCallActive()
            speakQuestionsIfReady()
        } catch {
            if let call = activeCall { failCall(uuid: call.uuid, message: error.localizedDescription) }
        }
    }

    func provider(_: CXProvider, didDeactivate session: AVAudioSession) {
        log("CallKit 오디오 비활성화")
        setEngine(.none)
        questionSpeaker.stop()
        isAudioSessionActive = false
        analysisWriter?.setMuted(true)
    }
}
