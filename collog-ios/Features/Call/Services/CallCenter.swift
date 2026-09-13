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

    private struct PendingOutgoing {
        let uuid: UUID
        let calleeId: String
        let name: String
    }

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let registry = PKPushRegistry(queue: .main)
    @ObservationIgnored private let callController = CXCallController()
    @ObservationIgnored private var room = Room()

    @ObservationIgnored private lazy var provider: CXProvider = {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 1
        configuration.supportedHandleTypes = [.generic]
        return CXProvider(configuration: configuration)
    }()

    @ObservationIgnored private var pendingOutgoing: PendingOutgoing?
    @ObservationIgnored private var answeredCallIds: Set<String> = []
    @ObservationIgnored private var answeringCallIds: Set<String> = []
    @ObservationIgnored private var serverAccepted = false
    @ObservationIgnored private var callOwnerId: String?
    @ObservationIgnored private var microphoneTask: Task<Void, Never>?
    @ObservationIgnored private var muteTask: Task<Void, Never>?
    @ObservationIgnored private var statusUnavailable = false
    @ObservationIgnored private var recordingStopped = false
    @ObservationIgnored private var pendingCapture: AudioCaptureOptions?
    @ObservationIgnored private var analysisWriter: AnalysisPCMWriter?
    @ObservationIgnored private weak var analysisTrack: LocalAudioTrack?
    @ObservationIgnored private var rawCaptureRequired = false
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var deviceRegistrationTask: Task<Void, Never>?
    @ObservationIgnored private var needsDeviceRegistration = false
    @ObservationIgnored private let questionSpeaker = RingingQuestionSpeaker()
    @ObservationIgnored private var serverQuestions: [APIQuestion] = []
    @ObservationIgnored private var spokenCallId: String?
    @ObservationIgnored private var notificationAuthorizationTask: Task<Void, Never>?
    @ObservationIgnored private var reportNotificationsAuthorized = false
    @ObservationIgnored private var uploadBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private lazy var uploads: RawAudioUploadQueue? = {
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

    @ObservationIgnored private var isAudioSessionActive = false
    @ObservationIgnored private var isMediaConnected = false
    @ObservationIgnored private var didPublishMicrophone = false
    @ObservationIgnored private var microphoneReady = false

    private(set) var activeCall: ActiveCall?
    var hasCallInProgress: Bool { activeCall != nil || pendingOutgoing != nil }
    private(set) var voipToken: String?
    private(set) var apnsToken: String?
    private(set) var events: [String] = []
    private(set) var deviceRegistrationError: String?
    private(set) var notificationPermissionError: String?
    var callError: String?
    private(set) var needsMicrophoneSettings = false

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

    private func prepareSignOut() async {
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

    private func endUploadBackgroundTask() {
        guard uploadBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(uploadBackgroundTask)
        uploadBackgroundTask = .invalid
    }

    func setRemoteNotificationToken(_ deviceToken: Data) {
        apnsToken = deviceToken.hexString
        registerDeviceIfPossible()
    }

    func setRemoteNotificationError(_ message: String) {
        deviceRegistrationError = message
        log("APNs 등록 실패: \(message)")
    }

    func registerDeviceIfPossible() {
        guard environment.session.isAuthenticated else { return }
        guard apnsToken != nil else {
            deviceRegistrationError = "통화 알림 등록을 기다리고 있어요"
            return
        }
        needsDeviceRegistration = true
        guard deviceRegistrationTask == nil else { return }
        deviceRegistrationTask = Task {
            defer { deviceRegistrationTask = nil }
            var failures = 0
            while needsDeviceRegistration, let apnsToken, environment.session.isAuthenticated {
                needsDeviceRegistration = false
                let ownerId = environment.session.user?.id
                do {
                    _ = try await environment.api.registerDevice(
                        token: apnsToken,
                        voipToken: voipToken,
                        callNotificationsEnabled: environment.settings.callNotificationsEnabled,
                        pushToken: apnsToken,
                        reportNotificationsEnabled: environment.settings.reportNotificationsEnabled
                            && reportNotificationsAuthorized
                    )
                    deviceRegistrationError = nil
                    failures = 0
                    log("기기 등록 완료")
                } catch {
                    deviceRegistrationError = error.localizedDescription
                    log("기기 등록 실패: \(error.localizedDescription)")
                    failures += 1
                    if failures < 4, CallSafety.canRetry(error), ownerId == environment.session.user?.id {
                        needsDeviceRegistration = true
                        do { try await Task.sleep(for: .seconds(5 * failures)) } catch { return }
                    }
                }
            }
        }
    }

    func updateNotificationAuthorization() {
        guard notificationAuthorizationTask == nil else { return }
        notificationAuthorizationTask = Task {
            defer { notificationAuthorizationTask = nil }
            let center = UNUserNotificationCenter.current()
            var settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined, environment.settings.reportNotificationsEnabled {
                do {
                    _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                    settings = await center.notificationSettings()
                } catch {
                    notificationPermissionError = error.localizedDescription
                    return
                }
            }
            reportNotificationsAuthorized = [.authorized, .provisional, .ephemeral]
                .contains(settings.authorizationStatus)
            notificationPermissionError = environment.settings.reportNotificationsEnabled
                && !reportNotificationsAuthorized ? "iPhone 설정에서 콜록 알림을 허용해주세요" : nil
            registerDeviceIfPossible()
        }
    }

    func updateQuestionVoicePreference() {
        if environment.settings.questionVoiceEnabled {
            speakQuestionsIfReady()
        } else {
            questionSpeaker.stop()
            spokenCallId = nil
        }
    }

    private func speakQuestionsIfReady() {
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

    private func connectMedia(
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

    private func publishMicrophoneIfReady() {
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

    private func attachAnalysisWriter(to publication: LocalTrackPublication?) {
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

    private func finishAnalysisRecording(callId: String) {
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

    private func discardAnalysisRecording() {
        if let writer = analysisWriter { analysisTrack?.remove(audioRenderer: writer) }
        analysisWriter?.discard()
        analysisWriter = nil
        analysisTrack = nil
        rawCaptureRequired = false
        if let callId = activeCall?.id { uploads?.discard(callId: callId) }
    }

    private func applyRecordingStatus(_ enabled: Bool, message: String?) {
        let shouldStop = !enabled && !recordingStopped
        if !enabled { recordingStopped = true }
        activeCall?.recordingEnabled = enabled && !recordingStopped
        if !enabled {
            if shouldStop { discardAnalysisRecording() }
            activeCall?.notice = message ?? "이번 통화는 녹음과 분석 없이 진행해요."
        }
    }

    private func teardown() {
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

    private func failCall(uuid: UUID, message: String, microphone: Bool = false) {
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

    private func monitorCall(_ callId: String) {
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

    private func finishRemoteCall(reason: CXCallEndedReason = .remoteEnded) {
        guard let call = activeCall else { return }
        provider.reportCall(with: call.uuid, endedAt: nil, reason: reason)
        teardown()
    }

    private func handleMediaError(_ error: Error, uuid: UUID) {
        guard activeCall?.uuid == uuid else { return }
        if (error as? LiveKitError)?.type == .roomDeleted {
            log("서버 통화 종료")
            finishRemoteCall()
        } else {
            failCall(uuid: uuid, message: error.localizedDescription)
        }
    }

    private func prepareCallAudio() throws {
        try AVAudioSession.sharedInstance().setCategory(
            .playAndRecord, mode: .voiceChat, options: [.mixWithOthers]
        )
        let configuration = provider.configuration
        provider.configuration = configuration
        log("CallKit 오디오 준비 완료")
    }

    private func markCallActive() {
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
    private func setEngine(_ availability: AudioEngineAvailability) -> Bool {
        do {
            try AudioManager.shared.setEngineAvailability(availability)
            return true
        } catch {
            log("오디오 엔진 설정 실패: \(error.localizedDescription)")
            return false
        }
    }
}

extension CallCenter: PKPushRegistryDelegate {
    nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate credentials: PKPushCredentials,
        for type: PKPushType
    ) {
        MainActor.assumeIsolated {
            voipToken = credentials.token.hexString
            log("VoIP 토큰 수신")
            registerDeviceIfPossible()
        }
    }

    nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        MainActor.assumeIsolated {
            voipToken = nil
            registerDeviceIfPossible()
        }
    }

    nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        MainActor.assumeIsolated {
            let call = payload.dictionaryPayload["call"] as? [String: Any] ?? [:]
            let uuid = (call["callUUID"] as? String).flatMap(UUID.init) ?? UUID()
            let callerName = call["callerName"] as? String ?? "콜록"
            let callerId = call["callerId"] as? String
            let contact = environment.family.contacts.first { contact in
                contact.userId == callerId || contact.name == callerName
            }
            let questions = environment.family.questions(for: contact).map(\.text)

            guard let callId = call["callId"] as? String else {
                reportAndImmediatelyEnd(uuid: uuid, completion: completion)
                return
            }
            guard CallSafety.acceptsPush(
                userId: environment.session.isAuthenticated ? environment.session.user?.id : nil,
                calleeId: call["calleeId"] as? String
            ) else {
                reportAndImmediatelyEnd(uuid: uuid, completion: completion)
                return
            }
            guard activeCall == nil, pendingOutgoing == nil else {
                if let activeCall, activeCall.id == callId {
                    let update = CXCallUpdate()
                    update.localizedCallerName = activeCall.peerName
                    provider.reportNewIncomingCall(with: activeCall.uuid, update: update) { _ in completion() }
                    return
                }
                reportAndImmediatelyEnd(uuid: uuid, completion: completion)
                declineIncomingCall(callId)
                return
            }
            if let expiresAt = call["expiresAt"] as? String,
               let expiry = Date.fromCollogTimestamp(expiresAt),
               expiry < Date() {
                log("만료된 push 무시: \(callId)")
                reportAndImmediatelyEnd(uuid: uuid, completion: completion)
                return
            }

            do {
                try prepareCallAudio()
            } catch {
                log("수신 오디오 준비 실패: \(error.localizedDescription)")
                reportAndImmediatelyEnd(uuid: uuid, completion: completion)
                declineIncomingCall(callId)
                return
            }

            callOwnerId = environment.session.user?.id
            activeCall = ActiveCall(
                id: callId,
                uuid: uuid,
                direction: .incoming,
                peerId: callerId,
                peerName: callerName,
                phase: .ringing,
                questions: questions
            )

            let update = CXCallUpdate()
            update.localizedCallerName = callerName
            update.remoteHandle = CXHandle(type: .generic, value: call["callerId"] as? String ?? "collog")
            update.hasVideo = false
            update.supportsHolding = false
            update.supportsGrouping = false
            update.supportsUngrouping = false
            update.supportsDTMF = false

            provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
                MainActor.assumeIsolated {
                    guard self?.activeCall?.uuid == uuid else {
                        completion()
                        return
                    }
                    if let error {
                        self?.failCall(uuid: uuid, message: error.localizedDescription)
                    } else {
                        self?.log("수신 통화 표시: \(callerName)")
                        self?.monitorCall(callId)
                    }
                    completion()
                }
            }
        }
    }

    private func declineIncomingCall(_ callId: String) {
        Task {
            do { try await environment.api.declineCall(callId: callId) }
            catch { log("수신 거절 실패: \(error.localizedDescription)") }
        }
    }

    private func reportAndImmediatelyEnd(uuid: UUID, completion: @escaping () -> Void) {
        let reportedUUID = activeCall?.uuid == uuid || pendingOutgoing?.uuid == uuid ? UUID() : uuid
        let update = CXCallUpdate()
        update.localizedCallerName = "콜록"
        provider.reportNewIncomingCall(with: reportedUUID, update: update) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.provider.reportCall(with: reportedUUID, endedAt: nil, reason: .unanswered)
                completion()
            }
        }
    }
}

extension CallCenter: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {
        MainActor.assumeIsolated {
            if let uuid = activeCall?.uuid ?? pendingOutgoing?.uuid {
                failCall(uuid: uuid, message: "통화 서비스가 중단되었어요. 다시 시도해주세요")
            } else {
                teardown()
            }
        }
    }

    nonisolated func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        MainActor.assumeIsolated {
            guard let action = action as? CXCallAction else { return }
            failCall(uuid: action.callUUID, message: "통화 요청 시간이 초과되었어요. 다시 시도해주세요")
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        MainActor.assumeIsolated {
            guard let pending = pendingOutgoing, pending.uuid == action.callUUID else {
                action.fail()
                return
            }
            Task {
                var actionFulfilled = false
                do {
                    let created = try await environment.api.createCall(calleeId: pending.calleeId)
                    guard pendingOutgoing?.uuid == pending.uuid else {
                        try? await environment.api.endCall(callId: created.callId)
                        action.fail()
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
                    action.fulfill()
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
                    if !actionFulfilled { action.fail() }
                    if activeCall?.uuid == pending.uuid {
                        handleMediaError(error, uuid: pending.uuid)
                    } else {
                        failCall(uuid: pending.uuid, message: error.localizedDescription)
                    }
                }
            }
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        MainActor.assumeIsolated {
            guard let call = activeCall, call.uuid == action.callUUID, call.direction == .incoming else {
                action.fail()
                return
            }
            guard !answeredCallIds.contains(call.id), !answeringCallIds.contains(call.id) else {
                action.fail()
                return
            }
            answeringCallIds.insert(call.id)
            Task {
                var actionFulfilled = false
                let requestId = UUID().uuidString
                defer { answeringCallIds.remove(call.id) }
                do {
                    let permitted = await AVAudioApplication.requestRecordPermission()
                    guard activeCall?.uuid == call.uuid else {
                        action.fail()
                        return
                    }
                    guard permitted else {
                        action.fail()
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
                        action.fail()
                        return
                    }
                    answeredCallIds.insert(call.id)
                    serverAccepted = true
                    rawCaptureRequired = accepted.rawCaptureRequired
                    applyRecordingStatus(
                        accepted.recordingEnabled ?? accepted.rawCaptureRequired,
                        message: nil
                    )
                    action.fulfill()
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
                    if !actionFulfilled { action.fail() }
                    if case let APIError.server(status, _, _) = error, [409, 410].contains(status) {
                        guard activeCall?.id == call.id else { return }
                        finishRemoteCall(reason: status == 409 ? .answeredElsewhere : .unanswered)
                        return
                    }
                    handleMediaError(error, uuid: call.uuid)
                }
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

    nonisolated func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        MainActor.assumeIsolated {
            guard let call = activeCall, call.uuid == action.callUUID else {
                action.fail()
                return
            }
            activeCall?.isMuted = action.isMuted
            analysisWriter?.setMuted(action.isMuted)
            let targetRoom = room
            let previousMute = muteTask
            muteTask = Task {
                await previousMute?.value
                await microphoneTask?.value
                guard room === targetRoom, activeCall?.uuid == call.uuid else {
                    action.fail()
                    return
                }
                do {
                    if isMediaConnected || didPublishMicrophone {
                        let publication = try await targetRoom.localParticipant.setMicrophone(enabled: !action.isMuted)
                        guard room === targetRoom, activeCall?.uuid == call.uuid else {
                            action.fail()
                            return
                        }
                        attachAnalysisWriter(to: publication)
                    }
                    action.fulfill()
                } catch {
                    action.fail()
                    failCall(uuid: call.uuid, message: "마이크 상태를 바꾸지 못해 통화를 종료했어요.")
                }
            }
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        MainActor.assumeIsolated {
            guard activeCall?.uuid == action.callUUID || pendingOutgoing?.uuid == action.callUUID else {
                action.fulfill()
                return
            }
            let call = activeCall
            let answered = call.map { $0.direction == .outgoing || answeredCallIds.contains($0.id) } ?? false
            action.fulfill()
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
    }

    nonisolated func provider(_ provider: CXProvider, didActivate session: AVAudioSession) {
        MainActor.assumeIsolated {
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
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate session: AVAudioSession) {
        MainActor.assumeIsolated {
            log("CallKit 오디오 비활성화")
            setEngine(.none)
            questionSpeaker.stop()
            isAudioSessionActive = false
            analysisWriter?.setMuted(true)
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

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
