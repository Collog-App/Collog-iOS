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
    }

    private struct PendingOutgoing {
        let uuid: UUID
        let calleeId: String
        let name: String
    }

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let registry = PKPushRegistry(queue: .main)
    @ObservationIgnored private let callController = CXCallController()
    @ObservationIgnored private let room = Room()

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
    @ObservationIgnored private var pendingCapture: AudioCaptureOptions?
    @ObservationIgnored private var analysisWriter: AnalysisPCMWriter?
    @ObservationIgnored private weak var analysisTrack: LocalAudioTrack?
    @ObservationIgnored private var rawCaptureRequired = false
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var isDisconnecting = false
    @ObservationIgnored private var deviceRegistrationTask: Task<Void, Never>?
    @ObservationIgnored private var needsDeviceRegistration = false
    @ObservationIgnored private let questionSpeaker = RingingQuestionSpeaker()
    @ObservationIgnored private var serverQuestions: [APIQuestion] = []
    @ObservationIgnored private var spokenCallId: String?
    @ObservationIgnored private var notificationAuthorizationTask: Task<Void, Never>?
    @ObservationIgnored private var reportNotificationsAuthorized = false

    @ObservationIgnored private var isAudioSessionActive = false
    @ObservationIgnored private var didPublishMicrophone = false

    private(set) var activeCall: ActiveCall?
    private(set) var voipToken: String?
    private(set) var apnsToken: String?
    private(set) var events: [String] = []
    private(set) var deviceRegistrationError: String?
    private(set) var notificationPermissionError: String?

    init(environment: AppEnvironment) {
        self.environment = environment
        super.init()
    }

    func start() {
        AudioManager.shared.audioSession.isAutomaticConfigurationEnabled = false
        setEngine(.none)
        provider.setDelegate(self, queue: nil)
        room.add(delegate: self)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        UIApplication.shared.registerForRemoteNotifications()
        if environment.session.isAuthenticated { updateNotificationAuthorization() }
        log("PushKit 등록 시작")
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
            while needsDeviceRegistration, let apnsToken, environment.session.isAuthenticated {
                needsDeviceRegistration = false
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
                    log("기기 등록 완료")
                } catch {
                    deviceRegistrationError = error.localizedDescription
                    log("기기 등록 실패: \(error.localizedDescription)")
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
        questionSpeaker.speak(serverQuestions) { [weak self] event in
            self?.log(event)
        }
    }

    func startOutgoingCall(calleeId: String, name: String, questions _: [String]) {
        guard activeCall == nil, pendingOutgoing == nil, !isDisconnecting else { return }
        guard environment.session.user?.role == UserRoleOption.child.rawValue else { return }
        let uuid = UUID()
        pendingOutgoing = PendingOutgoing(
            uuid: uuid,
            calleeId: calleeId,
            name: name
        )
        let action = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: name))
        action.contactIdentifier = name
        callController.request(CXTransaction(action: action)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                self?.pendingOutgoing = nil
                self?.log("발신 실패: \(error.localizedDescription)")
            }
        }
    }

    func endActiveCall() {
        guard let uuid = activeCall?.uuid ?? pendingOutgoing?.uuid else { return }
        callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { [weak self] error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                self?.log("종료 실패: \(error.localizedDescription)")
            }
        }
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
        guard activeCall?.id == callId else {
            await room.disconnect()
            throw CancellationError()
        }
        log("LiveKit 접속: room=\(roomName)")
        publishMicrophoneIfReady()
    }

    private func publishMicrophoneIfReady() {
        guard !didPublishMicrophone, isAudioSessionActive, let options = pendingCapture else { return }
        didPublishMicrophone = true
        Task {
            do {
                let publication = try await room.localParticipant.setMicrophone(
                    enabled: true,
                    captureOptions: options
                )
                log("마이크 publish 완료")
                attachAnalysisWriter(to: publication)
            } catch {
                didPublishMicrophone = false
                log("마이크 publish 실패: \(error.localizedDescription)")
            }
        }
    }

    private func attachAnalysisWriter(to publication: LocalTrackPublication?) {
        guard analysisWriter == nil, rawCaptureRequired else { return }
        let resolved = publication?.track ?? room.localParticipant.audioTracks.first?.track
        guard let track = resolved as? LocalAudioTrack else {
            log("분석 PCM 실패: local audio track을 찾지 못했다")
            return
        }

        let writer = AnalysisPCMWriter()
        do {
            try writer.start()
        } catch {
            log("분석 PCM 시작 실패: \(error.localizedDescription)")
            return
        }
        track.add(audioRenderer: writer)
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

        Task {
            do {
                let upload = try await environment.api.rawAudioUploadURL(
                    callId: callId,
                    durationSec: duration,
                    sampleRate: Int(AnalysisPCMWriter.sampleRate)
                )
                try await environment.api.uploadRawAudio(fileURL: fileURL, to: upload.uploadUrl)
                try await environment.api.completeRawAudio(callId: callId, assetId: upload.assetId)
                log("분석 PCM 업로드 완료 (\(Int(duration))초)")
            } catch {
                log("분석 PCM 업로드 실패: \(error.localizedDescription)")
            }
            try? FileManager.default.removeItem(at: fileURL)
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
            finishAnalysisRecording(callId: callId)
        } else {
            analysisTrack = nil
            analysisWriter?.discard()
            analysisWriter = nil
        }
        rawCaptureRequired = false
        didPublishMicrophone = false
        pendingCapture = nil
        pendingOutgoing = nil
        activeCall = nil
        isDisconnecting = true
        Task {
            await room.disconnect()
            setEngine(.none)
            isDisconnecting = false
        }
    }

    private func monitorCall(_ callId: String) {
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, activeCall?.id == callId else { return }
                do {
                    let status = try await environment.api.callStatus(callId: callId)
                    guard !Task.isCancelled, activeCall?.id == callId else { return }
                    if status.hasEnded {
                        finishRemoteCall()
                        return
                    }
                    if status.state == "ACTIVE" { questionSpeaker.stop() }
                } catch APIError.unauthenticated {
                    finishRemoteCall(reason: .failed)
                    return
                } catch {
                    if Task.isCancelled { return }
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

    private func setEngine(_ availability: AudioEngineAvailability) {
        do {
            try AudioManager.shared.setEngineAvailability(availability)
        } catch {
            log("오디오 엔진 설정 실패: \(error.localizedDescription)")
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
            guard activeCall == nil, pendingOutgoing == nil, !isDisconnecting else {
                reportAndImmediatelyEnd(uuid: uuid, completion: completion)
                return
            }
            if let expiresAt = call["expiresAt"] as? String,
               let expiry = Date.fromCollogTimestamp(expiresAt),
               expiry < Date() {
                log("만료된 push 무시: \(callId)")
                reportAndImmediatelyEnd(uuid: uuid, completion: completion)
                return
            }

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

            provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
                MainActor.assumeIsolated {
                    if let error {
                        self?.log("CallKit 보고 실패: \(error.localizedDescription)")
                        self?.activeCall = nil
                    } else {
                        self?.log("수신 통화 표시: \(callerName)")
                        self?.monitorCall(callId)
                    }
                    completion()
                }
            }
        }
    }

    private func reportAndImmediatelyEnd(uuid: UUID, completion: @escaping () -> Void) {
        let update = CXCallUpdate()
        update.localizedCallerName = "콜록"
        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.provider.reportCall(with: uuid, endedAt: nil, reason: .unanswered)
                completion()
            }
        }
    }
}

extension CallCenter: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {
        MainActor.assumeIsolated { teardown() }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        MainActor.assumeIsolated {
            guard let pending = pendingOutgoing, pending.uuid == action.callUUID else {
                action.fail()
                return
            }
            Task {
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
                        notice: created.recordingEnabled ? nil : created.recordingDisabledMessage
                    )
                    serverQuestions = created.questions
                    rawCaptureRequired = false
                    action.fulfill()
                    provider.reportOutgoingCall(with: pending.uuid, startedConnectingAt: nil)
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
                    log("발신 실패: \(error.localizedDescription)")
                    action.fail()
                    if let call = activeCall {
                        try? await environment.api.endCall(callId: call.id)
                        finishRemoteCall(reason: .failed)
                    } else {
                        teardown()
                    }
                }
            }
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        MainActor.assumeIsolated {
            guard let call = activeCall, call.direction == .incoming else {
                action.fail()
                return
            }
            activeCall?.phase = .connecting
            answeredCallIds.insert(call.id)
            Task {
                do {
                    let accepted = try await environment.api.acceptCall(callId: call.id)
                    guard activeCall?.id == call.id else {
                        try? await environment.api.endCall(callId: call.id)
                        action.fail()
                        return
                    }
                    rawCaptureRequired = accepted.rawCaptureRequired
                    try await connectMedia(
                        callId: call.id,
                        url: accepted.livekitUrl,
                        token: accepted.accessToken,
                        roomName: accepted.roomName,
                        constraints: accepted.audioConstraints
                    )
                    guard activeCall?.id == call.id else {
                        action.fail()
                        return
                    }
                    activeCall?.phase = .active
                    action.fulfill()
                } catch {
                    log("수락 실패: \(error.localizedDescription)")
                    action.fail()
                    try? await environment.api.endCall(callId: call.id)
                    finishRemoteCall(reason: .failed)
                }
            }
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        MainActor.assumeIsolated {
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
            do {
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers])
                setEngine(.default)
                isAudioSessionActive = true
                publishMicrophoneIfReady()
                speakQuestionsIfReady()
            } catch {
                log("오디오 초기화 실패: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate session: AVAudioSession) {
        MainActor.assumeIsolated {
            setEngine(.none)
            questionSpeaker.stop()
            isAudioSessionActive = false
        }
    }
}

extension CallCenter: RoomDelegate {
    nonisolated func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        Task { @MainActor in
            guard !isDisconnecting else { return }
            finishRemoteCall(reason: error == nil ? .remoteEnded : .failed)
        }
    }

    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in
            guard let call = activeCall else { return }
            questionSpeaker.stop()
            activeCall?.phase = .active
            if call.direction == .outgoing {
                provider.reportOutgoingCall(with: call.uuid, connectedAt: nil)
            }
            log("상대 참가: \(participant.identity?.stringValue ?? "-")")
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            log("상대 퇴장")
            endActiveCall()
        }
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
