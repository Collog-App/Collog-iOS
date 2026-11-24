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
        if let question = postCallQuestion, question.ownerId != environment.session.user?.id {
            postCallQuestion = nil
        }
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
        postCallQuestion = nil
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

    func answerIncomingCall() {
        guard canAnswerIncomingCall, let call = activeCall else { return }
        incomingAnswerRequested = true
        incomingAnswerError = nil
        let action = CXAnswerCallAction(call: call.uuid)
        callController.request(CXTransaction(action: action)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                guard let self, activeCall?.uuid == call.uuid,
                      !answeringCallIds.contains(call.id), !answeredCallIds.contains(call.id) else { return }
                incomingAnswerRequested = false
                incomingAnswerError = "전화를 받지 못했어요. 다시 시도해주세요."
                log("수신 요청 실패: \(error.localizedDescription)")
            }
        }
    }

    func endActiveCall() {
        guard let uuid = activeCall?.uuid ?? pendingOutgoing?.uuid else { return }
        callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { [weak self] error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                // 스스로 끊은 것이라 연결 실패로 남기지 않는다
                self?.failCall(uuid: uuid, message: error.localizedDescription, failure: nil)
            }
        }
    }

    /// 통화 뒤 한 줄 질문: 건 사람이고, 통화가 실제로 연결됐었고, 그 통화에 추천 질문이 보였을 때만
    /// 「통화 종료」 화면에서 묻는다. 끝나는 통화를 정리(`teardown`)하기 전에 부른다.
    func offerPostCallQuestion() {
        guard let call = activeCall, call.direction == .outgoing, call.wasConnected, !call.questions.isEmpty,
              let ownerId = callOwnerId, ownerId == environment.session.user?.id,
              environment.session.isAuthenticated, !environment.settings.isGuestMode else { return }
        postCallQuestion = PostCallQuestion(
            callId: call.id, peerId: call.peerId, peerName: call.peerName, ownerId: ownerId
        )
    }

    func answerPostCallQuestion(_ answer: PostCallQuestion.Answer) {
        guard let question = postCallQuestion else { return }
        postCallQuestion = nil
        guard question.ownerId == environment.session.user?.id else { return }
        environment.usage.record(
            .postCallAnswer, code: answer.rawValue, subjectId: question.peerId, callId: question.callId,
            using: environment
        )
    }

    /// 답하지 않고 닫으면 아무것도 남기지 않는다.
    func dismissPostCallQuestion() {
        postCallQuestion = nil
    }

    /// 이용 기록 `call_connect_failed`: 한 번도 연결되지 못한 통화가 실패로 끝났을 때만 남긴다.
    func recordConnectFailure(_ failure: CallConnectFailure) {
        guard activeCall?.wasConnected != true else { return }
        environment.usage.record(
            .callConnectFailed, code: failure.rawValue, callId: activeCall?.id, using: environment
        )
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
        audioRouter.deactivate()
        audioDiagnostics = nil
        isAudioSessionActive = false
        isMediaConnected = false
        didPublishMicrophone = false
        microphoneReady = false
        pendingCapture = nil
        pendingOutgoing = nil
        activeCall = nil
        incomingCallReported = false
        incomingAnswerRequested = false
        incomingAnswerError = nil
        let previousRoom = room
        previousRoom.remove(delegate: self)
        room = Room()
        room.add(delegate: self)
        setEngine(.none)
        Task { await previousRoom.disconnect() }
    }

    /// `failure`: 연결되지 못한 채 끝났을 때 이용 기록에 남길 코드. 스스로 끊은 경우처럼 실패가 아니면 nil.
    func failCall(
        uuid: UUID, message: String, microphone: Bool = false, failure: CallConnectFailure? = .other
    ) {
        guard activeCall?.uuid == uuid || pendingOutgoing?.uuid == uuid else { return }
        let call = activeCall
        let acceptedHere = call.map { answeredCallIds.contains($0.id) } ?? false
        if let failure { recordConnectFailure(microphone ? .microphonePermission : failure) }
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
                        recordConnectFailure(CallConnectFailure(error))
                        discardAnalysisRecording()
                        finishRemoteCall(reason: .failed)
                        return
                    }
                    activeCall?.notice = "통화 상태를 확인하고 있어요. 인터넷 상태를 확인해 주세요."
                    statusUnavailable = true
                    if Date().timeIntervalSince(lastSuccess) >= 30 {
                        if let call = activeCall {
                            failCall(
                                uuid: call.uuid, message: "통화 상태를 확인할 수 없어 통화를 종료했어요.",
                                failure: .network
                            )
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
        if reason == .remoteEnded { offerPostCallQuestion() }
        provider.reportCall(with: call.uuid, endedAt: nil, reason: reason)
        teardown()
    }

    func handleMediaError(_ error: Error, uuid: UUID) {
        guard activeCall?.uuid == uuid else { return }
        if (error as? LiveKitError)?.type == .roomDeleted {
            log("서버 통화 종료")
            finishRemoteCall()
        } else {
            failCall(uuid: uuid, message: error.localizedDescription, failure: CallConnectFailure(error))
        }
    }
}
