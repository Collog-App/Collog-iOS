//
//  CallCenter+AudioRoute.swift
//  collog-ios
//
//  Route observation and diagnostics based on Collog-Server PR #10 by hyojae02.
//

import AVFAudio
import Foundation
import LiveKit

extension CallCenter {
    /// TestFlight installs carry a sandbox receipt; App Store installs carry `receipt`.
    /// Deprecated since iOS 18, but synchronous and local, unlike `AppTransaction.shared`.
    static let showsAudioDiagnostics = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"

    func observeAudioRoute() {
        guard audioRouteObserver == nil else { return }
        audioRouteObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            MainActor.assumeIsolated { self?.audioRouteChanged(reason: reason) }
        }
        audioVolumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.refreshAudioRoute(event: "volume") }
        }
    }

    private func audioRouteChanged(reason: AVAudioSession.RouteChangeReason?) {
        guard isAudioSessionActive else { return }
        // Re-select only on accessory add/remove. Our own category and override
        // changes also post this notification and must not loop back here.
        if reason == .newDeviceAvailable || reason == .oldDeviceUnavailable {
            do {
                try audioRouter.externalDeviceChanged()
            } catch {
                log("외부 오디오 경로 전환 실패: \(error.localizedDescription)")
            }
        }
        refreshAudioRoute(event: "route-\(reason?.rawValue ?? 0)")
    }

    /// Mirrors LiveKit's `AudioManager.updateExpectedPlatformVoiceProcessing`: before
    /// capture starts the resolved state cannot be read, so it is derived from the
    /// capture options. Unknown options keep LiveKit's default expectation (true).
    var platformVoiceProcessingExpected: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard let options = pendingCapture else { return true }
        let requestsPlatform = (options.echoCancellation && options.echoCancellationMode != .software)
            || (options.noiseSuppression && options.noiseSuppressionMode != .software)
        return requestsPlatform && AudioManager.shared.isPlatformVoiceProcessingAllowed
        #endif
    }

    /// Live readback from the input node, nil until a local microphone track captures.
    /// The ADM reads `AVAudioEngine.inputNode`, which must not be created on a
    /// playout-only engine (for example when the call started muted).
    var platformVoiceProcessingActive: Bool? {
        guard microphoneReady, !room.localParticipant.audioTracks.isEmpty else { return nil }
        let state = AudioManager.shared.platformVoiceProcessingState
        return state.voiceProcessingEnabled.isActive && !state.voiceProcessingBypassed.isActive
    }

    /// Matches the session mode to the voice processing that capture resolved to.
    func syncAudioRouteAfterCapture(event: String) {
        do {
            try audioRouter.microphoneDidStart(
                platformVoiceProcessing: platformVoiceProcessingActive ?? platformVoiceProcessingExpected
            )
        } catch {
            log("마이크 시작 후 출력 경로 복구 실패: \(error.localizedDescription)")
        }
        refreshAudioRoute(event: event)
    }

    func refreshAudioRoute(event: String) {
        guard isAudioSessionActive, activeCall != nil else { return }
        let isSpeaker = audioRouter.output == .speaker
        if activeCall?.isSpeakerEnabled != isSpeaker { activeCall?.isSpeakerEnabled = isSpeaker }

        // Port types only: device names can contain personal names.
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: "+")
        let inputs = session.currentRoute.inputs.map(\.portType.rawValue).joined(separator: "+")
        let mode = session.mode.rawValue.replacingOccurrences(of: "AVAudioSessionMode", with: "")
        let bluetooth = [
            session.categoryOptions.contains(.allowBluetoothHFP) ? "HFP" : nil,
            session.categoryOptions.contains(.allowBluetoothA2DP) ? "A2DP" : nil
        ].compactMap(\.self).joined(separator: "+")
        let vpio = platformVoiceProcessingActive.map { $0 ? "on" : "off" } ?? "-"
        let line = "out=\(outputs.isEmpty ? "-" : outputs) mode=\(mode) bt=\(bluetooth.isEmpty ? "-" : bluetooth)"
            + " vpio=\(vpio) vol=\(String(format: "%.2f", session.outputVolume))"
        if Self.showsAudioDiagnostics, audioDiagnostics != line { audioDiagnostics = line }
        log("오디오[\(event)] \(line) in=\(inputs.isEmpty ? "-" : inputs)")
    }
}
