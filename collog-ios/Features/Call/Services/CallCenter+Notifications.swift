//
//  CallCenter+Notifications.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import CallKit
import PushKit
import UserNotifications

extension CallCenter {
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
}

extension CallCenter: @MainActor PKPushRegistryDelegate {
    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate credentials: PKPushCredentials,
        for type: PKPushType
    ) {
        voipToken = credentials.token.hexString
        log("VoIP 토큰 수신")
        registerDeviceIfPossible()
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        voipToken = nil
        registerDeviceIfPossible()
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        let response = IncomingPushCompletion(completion)
        let call = payload.dictionaryPayload["call"] as? [String: Any] ?? [:]
        let uuid = (call["callUUID"] as? String).flatMap(UUID.init) ?? UUID()
        let callerName = call["callerName"] as? String ?? "콜록"
        let callerId = call["callerId"] as? String
        let contact = environment.family.contacts.first { contact in
            contact.userId == callerId || contact.name == callerName
        }
        let questions = environment.family.questions(for: contact).map(\.text)

        guard let callId = call["callId"] as? String else {
            reportAndImmediatelyEnd(uuid: uuid, completion: response)
            return
        }
        guard CallSafety.acceptsPush(
            userId: environment.session.isAuthenticated ? environment.session.user?.id : nil,
            calleeId: call["calleeId"] as? String
        ) else {
            reportAndImmediatelyEnd(uuid: uuid, completion: response)
            return
        }
        guard activeCall == nil, pendingOutgoing == nil else {
            if let activeCall, activeCall.id == callId {
                let update = CXCallUpdate()
                update.localizedCallerName = activeCall.peerName
                provider.reportNewIncomingCall(with: activeCall.uuid, update: update) { _ in
                    Task { @MainActor in response.finish() }
                }
                return
            }
            reportAndImmediatelyEnd(uuid: uuid, completion: response)
            declineIncomingCall(callId)
            return
        }
        if let expiresAt = call["expiresAt"] as? String,
           let expiry = Date.fromCollogTimestamp(expiresAt),
           expiry < Date() {
            log("만료된 push 무시: \(callId)")
            reportAndImmediatelyEnd(uuid: uuid, completion: response)
            return
        }

        do {
            try prepareCallAudio()
        } catch {
            log("수신 오디오 준비 실패: \(error.localizedDescription)")
            reportAndImmediatelyEnd(uuid: uuid, completion: response)
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
            Task { @MainActor [weak self] in
                guard self?.activeCall?.uuid == uuid else {
                    response.finish()
                    return
                }
                if let error {
                    self?.failCall(uuid: uuid, message: error.localizedDescription)
                } else {
                    self?.incomingCallReported = true
                    self?.log("수신 통화 표시: \(callerName)")
                    self?.monitorCall(callId)
                }
                response.finish()
            }
        }
    }

    private func declineIncomingCall(_ callId: String) {
        Task {
            do { try await environment.api.declineCall(callId: callId) }
            catch { log("수신 거절 실패: \(error.localizedDescription)") }
        }
    }

    private func reportAndImmediatelyEnd(uuid: UUID, completion response: IncomingPushCompletion) {
        let reportedUUID = activeCall?.uuid == uuid || pendingOutgoing?.uuid == uuid ? UUID() : uuid
        let update = CXCallUpdate()
        update.localizedCallerName = "콜록"
        provider.reportNewIncomingCall(with: reportedUUID, update: update) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.provider.reportCall(with: reportedUUID, endedAt: nil, reason: .unanswered)
                response.finish()
            }
        }
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
