//
//  CallAudioRouterTests.swift
//  collog-ios
//
//  Based on Collog-Server PR #10 by hyojae02 (ios/CollogTests/CallAudioRouterTests.swift).
//

import Testing
@testable import collog_ios

@MainActor
struct CallAudioRouterTests {
    @Test func startsOnSpeakerWithoutAnAccessory() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        #expect(session.output == .speaker)
        #expect(session.defaultsToSpeaker)
    }

    @Test func startsOnBluetoothWithoutForcingTheSpeaker() throws {
        let session = TestCallAudioSession()
        session.externalInputUID = "headset"
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        #expect(session.output == .external("Bluetooth"))
        #expect(session.speakerOverrides == 0)
        #expect(session.selectedInput == "headset")
    }

    @Test func preservesAnAlreadySelectedExternalOutput() throws {
        let session = TestCallAudioSession()
        session.output = .external("Wired headphones")
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        #expect(session.output == .external("Wired headphones"))
        #expect(session.speakerOverrides == 0)
    }

    @Test func configuresTheSessionBeforeDiscoveringBluetoothInputs() throws {
        let session = TestCallAudioSession()
        session.externalInputUID = "headset"
        session.requiresConfigurationToExposeInput = true
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        #expect(session.output == .external("Bluetooth"))
        #expect(session.selectedInput == "headset")
    }

    @Test func speakerToggleReturnsToBluetooth() throws {
        let session = TestCallAudioSession()
        session.externalInputUID = "headset"
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        try router.toggleSpeaker()
        #expect(session.output == .speaker)
        try router.toggleSpeaker()
        #expect(session.output == .external("Bluetooth"))
    }

    @Test func speakerToggleUsesReceiverWithoutAnAccessory() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        try router.toggleSpeaker()
        #expect(session.output == .receiver)
        try router.microphoneDidStart(platformVoiceProcessing: true)
        #expect(session.output == .receiver)
    }

    @Test func connectingBluetoothReleasesAnExistingSpeakerOverride() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        session.externalInputUID = "headset"
        try router.externalDeviceChanged()
        #expect(session.output == .external("Bluetooth"))
    }

    @Test func unpluggingHeadsetFallsBackToSpeaker() throws {
        let session = TestCallAudioSession()
        session.externalInputUID = "headset"
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        session.externalInputUID = nil
        session.output = .receiver
        try router.externalDeviceChanged()
        #expect(session.output == .speaker)
    }

    @Test func microphoneStartDoesNotStealAnExternalRoute() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        session.output = .external("Bluetooth")
        let count = session.operationCount
        try router.microphoneDidStart(platformVoiceProcessing: true)
        #expect(session.output == .external("Bluetooth"))
        #expect(session.operationCount == count)
    }

    @Test func microphoneStartRestoresSpeakerIfItFellBackToReceiver() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        session.output = .receiver
        try router.microphoneDidStart(platformVoiceProcessing: true)
        #expect(session.output == .speaker)
    }

    @Test func failedToggleKeepsActualStateAndCanBeRetried() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        session.rejectNextOverride = true
        #expect(throws: TestCallAudioSession.Failure.self) { try router.toggleSpeaker() }
        #expect(router.output == .speaker)
        try router.toggleSpeaker()
        #expect(router.output == .receiver)
    }

    @Test func failedActivationCanRecoverWhenAnAccessoryChanges() throws {
        let session = TestCallAudioSession()
        session.rejectNextOverride = true
        let router = CallAudioRouter(session: session)
        #expect(throws: TestCallAudioSession.Failure.self) { try router.activate(platformVoiceProcessing: true) }
        session.externalInputUID = "headset"
        try router.externalDeviceChanged()
        #expect(session.output == .external("Bluetooth"))
    }

    @Test func inactiveEventsDoNotTouchTheAudioSession() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.toggleSpeaker()
        try router.externalDeviceChanged()
        try router.microphoneDidStart(platformVoiceProcessing: false)
        #expect(session.operationCount == 0)
        try router.activate(platformVoiceProcessing: true)
        router.deactivate()
        let count = session.operationCount
        try router.externalDeviceChanged()
        try router.microphoneDidStart(platformVoiceProcessing: false)
        #expect(session.operationCount == count)
    }

    @Test func nextCallResetsThePreviousReceiverSelection() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        try router.toggleSpeaker()
        router.deactivate()
        try router.activate(platformVoiceProcessing: true)
        #expect(session.output == .speaker)
    }

    @Test func activationUsesTheChatModeOnlyWithPlatformVoiceProcessing() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        #expect(session.platformVoiceProcessing == true)
        router.deactivate()
        try router.activate(platformVoiceProcessing: false)
        #expect(session.platformVoiceProcessing == false)
    }

    @Test func microphoneStartSwitchesToMediaModeWhenVoiceProcessingIsOff() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        try router.toggleSpeaker()
        try router.toggleSpeaker()
        #expect(session.output == .speaker)
        try router.microphoneDidStart(platformVoiceProcessing: false)
        #expect(session.platformVoiceProcessing == false)
        #expect(session.output == .speaker)
        #expect(session.speakerOverrides == 2)
    }

    @Test func modeSwitchKeepsTheBluetoothSelection() throws {
        let session = TestCallAudioSession()
        session.externalInputUID = "headset"
        let router = CallAudioRouter(session: session)
        try router.activate(platformVoiceProcessing: true)
        try router.microphoneDidStart(platformVoiceProcessing: false)
        #expect(session.platformVoiceProcessing == false)
        #expect(session.output == .external("Bluetooth"))
        #expect(session.selectedInput == "headset")
    }

    @Test func preparingSetsTheCategoryWithoutActivatingRouting() throws {
        let session = TestCallAudioSession()
        let router = CallAudioRouter(session: session)
        try router.prepare(platformVoiceProcessing: true)
        #expect(session.defaultsToSpeaker)
        #expect(session.platformVoiceProcessing == true)
        let count = session.operationCount
        try router.toggleSpeaker()
        try router.externalDeviceChanged()
        #expect(session.operationCount == count)
    }
}

// Hardware boundary only: the real router decides configuration, input, override and order.
@MainActor
private final class TestCallAudioSession: CallAudioSession {
    enum Failure: Error { case overrideRejected }
    var output: CallAudioOutput = .receiver
    private var accessoryUID: String?
    var requiresConfigurationToExposeInput = false
    private var didConfigure = false
    var externalInputUID: String? {
        get { requiresConfigurationToExposeInput && !didConfigure ? nil : accessoryUID }
        set { accessoryUID = newValue }
    }
    var selectedInput: String?
    var defaultsToSpeaker = false
    var platformVoiceProcessing: Bool?
    var rejectNextOverride = false
    var operationCount = 0
    var speakerOverrides = 0
    private var speakerOverride = false

    func configure(defaultToSpeaker: Bool, platformVoiceProcessing: Bool) throws {
        operationCount += 1
        defaultsToSpeaker = defaultToSpeaker
        self.platformVoiceProcessing = platformVoiceProcessing
        didConfigure = true
    }

    func overrideSpeaker(_ enabled: Bool) throws {
        operationCount += 1
        if rejectNextOverride {
            rejectNextOverride = false
            throw Failure.overrideRejected
        }
        speakerOverride = enabled
        if enabled {
            speakerOverrides += 1
            output = .speaker
        } else if let selectedInput, selectedInput == externalInputUID {
            output = .external("Bluetooth")
        } else if !output.isExternal {
            output = defaultsToSpeaker ? .speaker : .receiver
        }
    }

    func preferInput(uid: String?) throws {
        operationCount += 1
        selectedInput = uid
        if !speakerOverride, let uid, uid == externalInputUID {
            output = .external("Bluetooth")
        }
    }
}
