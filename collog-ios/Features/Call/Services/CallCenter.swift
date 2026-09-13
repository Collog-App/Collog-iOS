//
//  CallCenter.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import AVFAudio
import CallKit
import LiveKit
import PushKit
import SwiftUI
import UIKit
import UserNotifications

@MainActor
@Observable
final class CallCenter: NSObject {
    struct ActiveCall: Identifiable {
        enum Direction {
            case incoming
            case outgoing
        }

        let id: String
        let uuid: UUID
        let direction: Direction
        let peerId: String?
        var peerName: String
        var phase: CallPhase
        let questions: [String]
        var notice: String?
        var recordingEnabled = false
        var isMuted = false
        var isSpeakerEnabled = false
    }

    struct PendingOutgoing {
        let uuid: UUID
        let calleeId: String
        let name: String
    }

    @ObservationIgnored let environment: AppEnvironment
    @ObservationIgnored let registry = PKPushRegistry(queue: .main)
    @ObservationIgnored let callController = CXCallController()
    @ObservationIgnored var room = Room()

    @ObservationIgnored lazy var provider: CXProvider = {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 1
        configuration.supportedHandleTypes = [.generic]
        return CXProvider(configuration: configuration)
    }()

    @ObservationIgnored var pendingOutgoing: PendingOutgoing?
    @ObservationIgnored var answeredCallIds: Set<String> = []
    @ObservationIgnored var answeringCallIds: Set<String> = []
    @ObservationIgnored var serverAccepted = false
    @ObservationIgnored var callOwnerId: String?
    @ObservationIgnored var microphoneTask: Task<Void, Never>?
    @ObservationIgnored var muteTask: Task<Void, Never>?
    @ObservationIgnored var statusUnavailable = false
    @ObservationIgnored var recordingStopped = false
    @ObservationIgnored var pendingCapture: AudioCaptureOptions?
    @ObservationIgnored var analysisWriter: AnalysisPCMWriter?
    @ObservationIgnored weak var analysisTrack: LocalAudioTrack?
    @ObservationIgnored var rawCaptureRequired = false
    @ObservationIgnored var statusTask: Task<Void, Never>?
    @ObservationIgnored var deviceRegistrationTask: Task<Void, Never>?
    @ObservationIgnored var needsDeviceRegistration = false
    @ObservationIgnored let questionSpeaker = RingingQuestionSpeaker()
    @ObservationIgnored var serverQuestions: [APIQuestion] = []
    @ObservationIgnored var spokenCallId: String?
    @ObservationIgnored var notificationAuthorizationTask: Task<Void, Never>?
    @ObservationIgnored var reportNotificationsAuthorized = false
    @ObservationIgnored var uploadBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored lazy var uploads: RawAudioUploadQueue? = {
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
    }()

    @ObservationIgnored var isAudioSessionActive = false
    @ObservationIgnored var isMediaConnected = false
    @ObservationIgnored var didPublishMicrophone = false
    @ObservationIgnored var microphoneReady = false

    var activeCall: ActiveCall?
    var hasCallInProgress: Bool { activeCall != nil || pendingOutgoing != nil }
    var voipToken: String?
    var apnsToken: String?
    private(set) var events: [String] = []
    var deviceRegistrationError: String?
    var notificationPermissionError: String?
    var callError: String?
    var needsMicrophoneSettings = false

    init(environment: AppEnvironment) {
        self.environment = environment
        super.init()
    }

    func start() {
        AnalysisPCMWriter.purgeAbandonedRecordings()
        environment.beforeSignOut = { [weak self] in await self?.prepareSignOut() }
        AudioManager.shared.audioSession.isAutomaticConfigurationEnabled = false
        setEngine(.none)
        provider.setDelegate(self, queue: nil)
        room.add(delegate: self)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        UIApplication.shared.registerForRemoteNotifications()
        if environment.session.isAuthenticated { updateNotificationAuthorization() }
        log("PushKit 등록 시작")
        resumePendingUploads()
    }

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

    func resumePendingUploads() {
        uploads?.discardInvalidOwners()
        guard let uploads, uploads.hasPending, uploadBackgroundTask == .invalid else { return }
        uploadBackgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor in
                self?.uploads?.pause()
                self?.endUploadBackgroundTask()
            }
        }
        Task {
            await uploads.resume()
            endUploadBackgroundTask()
        }
    }

    func endUploadBackgroundTask() {
        guard uploadBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(uploadBackgroundTask)
        uploadBackgroundTask = .invalid
    }

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

    func toggleMute() {
        guard let call = activeCall else { return }
        let action = CXSetMutedCallAction(call: call.uuid, muted: !call.isMuted)
        callController.request(CXTransaction(action: action)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.callError = error.localizedDescription }
        }
    }

    func toggleSpeaker() {
        guard let call = activeCall, isAudioSessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(call.isSpeakerEnabled ? .none : .speaker)
            activeCall?.isSpeakerEnabled = !call.isSpeakerEnabled
        } catch { callError = "통화 음성 출력을 바꾸지 못했어요." }
    }

    func log(_ message: String) {
        events.insert(message, at: 0)
        events = Array(events.prefix(30))
        print("[Collog] \(message)")
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
