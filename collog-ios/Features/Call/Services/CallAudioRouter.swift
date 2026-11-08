//
//  CallAudioRouter.swift
//  collog-ios
//
//  Based on Collog-Server PR #10 by hyojae02 (ios/Collog/CallAudioRouter.swift).
//  Routing decisions are kept apart from CallKit/LiveKit so accessory changes and
//  failures can be tested without simulator audio hardware.
//

import AVFAudio

enum CallAudioOutput: Equatable {
    case speaker
    case receiver
    case external(String)
    case unavailable

    var isExternal: Bool {
        if case .external = self { return true }
        return false
    }
}

protocol CallAudioSession: AnyObject {
    var output: CallAudioOutput { get }
    var externalInputUID: String? { get }
    func configure(defaultToSpeaker: Bool, platformVoiceProcessing: Bool) throws
    func preferInput(uid: String?) throws
    func overrideSpeaker(_ enabled: Bool) throws
}

final class CallAudioRouter {
    private enum Preference { case automatic, speaker, receiver }
    private let session: any CallAudioSession
    private var preference = Preference.automatic
    private var isActive = false
    private var platformVoiceProcessing = true

    var output: CallAudioOutput { session.output }

    init(session: any CallAudioSession) {
        self.session = session
    }

    /// Sets the call category before CallKit activates the session.
    func prepare(platformVoiceProcessing: Bool) throws {
        try session.configure(defaultToSpeaker: true, platformVoiceProcessing: platformVoiceProcessing)
    }

    // Called inside CallKit's didActivate. Automatic means an accessory when one is
    // connected, otherwise the speaker default, which survives route resets.
    func activate(platformVoiceProcessing: Bool) throws {
        preference = .automatic
        self.platformVoiceProcessing = platformVoiceProcessing
        isActive = true
        // Activation stays valid if an accessory disappears while it is selected.
        // A later route event, button press or microphone start retries.
        try applyPreference()
    }

    func deactivate() {
        isActive = false
        preference = .automatic
    }

    func toggleSpeaker() throws {
        guard isActive else { return }
        let previous = preference
        if output == .speaker {
            preference = session.externalInputUID == nil ? .receiver : .automatic
        } else {
            preference = .speaker
        }
        do {
            try applyPreference()
        } catch {
            preference = previous
            throw error
        }
    }

    // Only accessory add/remove events call this. Category and override changes
    // only refresh the UI, which prevents a route-change feedback loop.
    func externalDeviceChanged() throws {
        guard isActive else { return }
        preference = .automatic
        try applyPreference()
    }

    /// Re-applies the selection once capture starts. The session mode follows the
    /// voice processing that is actually running, read back after the publish.
    func microphoneDidStart(platformVoiceProcessing: Bool) throws {
        guard isActive else { return }
        let modeChanged = platformVoiceProcessing != self.platformVoiceProcessing
        self.platformVoiceProcessing = platformVoiceProcessing
        if !modeChanged {
            guard !output.isExternal else { return }
            if preference == .receiver, output == .receiver { return }
            if preference != .receiver, output == .speaker { return }
        }
        try applyPreference()
    }

    private func applyPreference() throws {
        // availableInputs depends on the configured category, so accessories are
        // looked up only after the category allows Bluetooth. defaultToSpeaker is a
        // fallback that, unlike an explicit override, yields to connected accessories.
        try session.configure(defaultToSpeaker: preference != .receiver, platformVoiceProcessing: platformVoiceProcessing)
        let input = preference == .automatic ? session.externalInputUID : nil
        try session.overrideSpeaker(false)
        try session.preferInput(uid: input)
        // .none releases an override; it does not force the receiver.
        if preference == .speaker { try session.overrideSpeaker(true) }
    }
}

final class SystemCallAudioSession: CallAudioSession {
    private let session = AVAudioSession.sharedInstance()

    var output: CallAudioOutput {
        let outputs = session.currentRoute.outputs
        // A mixed route is not reported as the speaker while an accessory is in use.
        if let external = outputs.first(where: {
            $0.portType != .builtInSpeaker && $0.portType != .builtInReceiver
        }) {
            return .external(external.portType.rawValue)
        }
        if outputs.contains(where: { $0.portType == .builtInSpeaker }) { return .speaker }
        if outputs.contains(where: { $0.portType == .builtInReceiver }) { return .receiver }
        return .unavailable
    }

    var externalInputUID: String? {
        let available = session.availableInputs ?? []
        let external = available.filter {
            [.headsetMic, .bluetoothHFP, .usbAudio, .lineIn].contains($0.portType)
        }
        // Keep a selected accessory rather than hopping between paired devices.
        if let current = session.currentRoute.inputs.first,
           external.contains(where: { $0.uid == current.uid }) {
            return current.uid
        }
        return external.first?.uid
    }

    // Same options as LiveKit's playAndRecord presets (AudioSessionConfiguration.swift).
    // The chat mode lowers playback unless Apple Voice Processing I/O is running, so
    // without it the media-tuned `.default` mode is used, as LiveKit's Media presets do.
    // `.default` does not imply Bluetooth HFP like `.voiceChat`, hence the explicit flags.
    // `.mixWithOthers` is left out on purpose: LiveKit dropped it from its playAndRecord
    // presets upstream (client-sdk-swift #1019, linked to #1011 "participant audio becomes
    // inaudible") because on the in-call path it lets another app hold the audio device and
    // races the WebRTC engine start (-66637).
    func configure(defaultToSpeaker: Bool, platformVoiceProcessing: Bool) throws {
        var options: AVAudioSession.CategoryOptions = [
            .allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay
        ]
        if defaultToSpeaker { options.insert(.defaultToSpeaker) }
        let mode: AVAudioSession.Mode = platformVoiceProcessing ? .voiceChat : .default
        if session.category != .playAndRecord || session.mode != mode || session.categoryOptions != options {
            try session.setCategory(.playAndRecord, mode: mode, options: options)
        }
    }

    func preferInput(uid: String?) throws {
        let input = uid.flatMap { id in session.availableInputs?.first { $0.uid == id } }
        if uid != nil, input == nil { throw RoutingError.accessoryUnavailable }
        if session.preferredInput?.uid != input?.uid {
            try session.setPreferredInput(input)
        }
    }

    func overrideSpeaker(_ enabled: Bool) throws {
        try session.overrideOutputAudioPort(enabled ? .speaker : .none)
    }

    private enum RoutingError: Error { case accessoryUnavailable }
}
