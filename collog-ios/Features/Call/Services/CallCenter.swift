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
    @ObservationIgnored lazy var uploads: RawAudioUploadQueue? = makeUploadQueue()

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

    func log(_ message: String) {
        events.insert(message, at: 0)
        events = Array(events.prefix(30))
        print("[Collog] \(message)")
    }

}
