//
//  CallCenter+Media.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import AVFAudio
import CallKit
import LiveKit

extension CallCenter {
    func updateQuestionVoicePreference() {
        if environment.settings.questionVoiceEnabled {
            speakQuestionsIfReady()
        } else {
            questionSpeaker.stop()
            spokenCallId = nil
        }
    }

    func speakQuestionsIfReady() {
        guard let call = activeCall, call.direction == .outgoing, call.phase == .ringing,
              isAudioSessionActive, environment.settings.questionVoiceEnabled,
              spokenCallId != call.id else { return }
        spokenCallId = call.id
        questionSpeaker.speak(serverQuestions, callId: call.id, api: environment.api) { [weak self] event in
            self?.log(event)
        }
    }

    func toggleMute() {
        guard let call = activeCall else { return }
        let action = CXSetMutedCallAction(call: call.uuid, muted: !call.isMuted)
        callController.request(CXTransaction(action: action)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor [weak self] in self?.callError = error.localizedDescription }
        }
    }

    func toggleSpeaker() {
        guard let call = activeCall, isAudioSessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(call.isSpeakerEnabled ? .none : .speaker)
            activeCall?.isSpeakerEnabled = !call.isSpeakerEnabled
        } catch { callError = "통화 음성 출력을 바꾸지 못했어요." }
    }

    func connectMedia(
        callId: String,
        url: String,
        token: String,
        roomName: String,
        constraints: AudioConstraints
    ) async throws {
        let room = room
        if constraints.autoGainControl || constraints.noiseSuppression {
            log("경고: 서버가 AGC/NS를 켜서 보냈다. 음향 분석 신뢰도가 떨어진다")
        }
        pendingCapture = AudioCaptureOptions(
            echoCancellation: constraints.echoCancellation,
            autoGainControl: constraints.autoGainControl,
            noiseSuppression: constraints.noiseSuppression,
            highpassFilter: false,
            typingNoiseDetection: false
        )
        try await room.connect(url: url, token: token)
        guard self.room === room, activeCall?.id == callId else {
            await room.disconnect()
            throw CancellationError()
        }
        log("LiveKit 접속: room=\(roomName)")
        isMediaConnected = true
        log("미디어 준비 완료, CallKit 오디오 활성화=\(isAudioSessionActive)")
        publishMicrophoneIfReady()
    }

    func publishMicrophoneIfReady() {
        guard !didPublishMicrophone, isAudioSessionActive, isMediaConnected, let options = pendingCapture,
              let call = activeCall else { return }
        let room = room
        didPublishMicrophone = true
        microphoneTask = Task {
            do {
                let publication = try await room.localParticipant.setMicrophone(
                    enabled: !call.isMuted,
                    captureOptions: options
                )
                guard self.room === room, activeCall?.uuid == call.uuid else { return }
                microphoneReady = true
                log("마이크 publish 완료")
                markCallActive()
                attachAnalysisWriter(to: publication)
            } catch {
                if (error as? LiveKitError)?.type == .roomDeleted {
                    handleMediaError(error, uuid: call.uuid)
                    return
                }
                failCall(uuid: call.uuid, message: "마이크를 사용할 수 없어요. \(error.localizedDescription)")
            }
        }
    }

    func prepareCallAudio() throws {
        try AVAudioSession.sharedInstance().setCategory(
            .playAndRecord, mode: .voiceChat, options: [.mixWithOthers]
        )
        let configuration = provider.configuration
        provider.configuration = configuration
        log("CallKit 오디오 준비 완료")
    }

    func markCallActive() {
        guard let call = activeCall, serverAccepted, isMediaConnected,
              isAudioSessionActive, microphoneReady else { return }
        questionSpeaker.stop()
        activeCall?.phase = .active
        if didPublishMicrophone { attachAnalysisWriter(to: nil) }
        if call.direction == .outgoing, call.phase != .active {
            provider.reportOutgoingCall(with: call.uuid, connectedAt: nil)
        }
    }

    @discardableResult
    func setEngine(_ availability: AudioEngineAvailability) -> Bool {
        do {
            try AudioManager.shared.setEngineAvailability(availability)
            return true
        } catch {
            log("오디오 엔진 설정 실패: \(error.localizedDescription)")
            return false
        }
    }
}

extension CallCenter: RoomDelegate {
    nonisolated func room(
        _ room: Room, didUpdateConnectionState connectionState: ConnectionState,
        from oldConnectionState: ConnectionState
    ) {
        Task { @MainActor in
            guard self.room === room, activeCall != nil else { return }
            if connectionState == .reconnecting {
                isMediaConnected = false
                analysisWriter?.setMuted(true)
                activeCall?.phase = .reconnecting
            } else if connectionState == .connected {
                isMediaConnected = true
                if didPublishMicrophone, let call = activeCall {
                    do {
                        _ = try await room.localParticipant.setMicrophone(enabled: !call.isMuted)
                        guard self.room === room, activeCall?.uuid == call.uuid else { return }
                    } catch {
                        failCall(uuid: call.uuid, message: "마이크 상태를 복구하지 못해 통화를 종료했어요.")
                        return
                    }
                }
                analysisWriter?.setMuted(activeCall?.isMuted ?? true)
                markCallActive()
                if !serverAccepted, activeCall?.direction == .outgoing { activeCall?.phase = .ringing }
            }
        }
    }
    nonisolated func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        Task { @MainActor in
            guard self.room === room else { return }
            if let error, let call = activeCall {
                handleMediaError(error, uuid: call.uuid)
                return
            }
            finishRemoteCall(reason: error == nil ? .remoteEnded : .failed)
        }
    }

    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in
            guard self.room === room, let call = activeCall else { return }
            guard call.peerId == participant.identity?.stringValue else { return }
            markCallActive()
            log("상대 참가: \(participant.identity?.stringValue ?? "-")")
        }
    }

    nonisolated func room(
        _ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication
    ) {
        Task { @MainActor in
            guard self.room === room, activeCall?.peerId == participant.identity?.stringValue else { return }
            log("상대 오디오 트랙 수신, muted=\(publication.isMuted)")
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            guard self.room === room, let call = activeCall,
                  call.peerId == participant.identity?.stringValue else { return }
            log("상대 퇴장")
            finishRemoteCall()
            do {
                try await environment.api.endCall(callId: call.id)
            } catch {
                log("종료 보고 실패: \(error.localizedDescription)")
            }
        }
    }
}
