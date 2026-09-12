import AVFAudio
import Foundation

@MainActor
final class RingingQuestionSpeaker: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var utterance: AVSpeechUtterance?
    private var playbackResult: Bool?
    private var task: Task<Void, Never>?
    private var generation = UUID()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ questions: [APIQuestion], onEvent: @escaping (String) -> Void) {
        stop()
        let generation = generation
        task = Task {
            defer {
                if self.generation == generation { task = nil }
            }
            for question in questions {
                guard !Task.isCancelled, self.generation == generation else { return }
                do {
                    if question.usesRemoteAudio {
                        do {
                            try await playRemote(question)
                        } catch {
                            try Task.checkCancellation()
                            onEvent("질문 음성 다운로드 또는 재생 실패, 기기 음성으로 재생해요")
                            try await speakLocal(question.text)
                        }
                    } else {
                        try await speakLocal(question.text)
                    }
                    try await Task.sleep(for: .milliseconds(700))
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        player?.stop()
        player = nil
        synthesizer.stopSpeaking(at: .immediate)
        utterance = nil
    }

    private func playRemote(_ question: APIQuestion) async throws {
        guard let address = question.ttsAssetUrl, let url = URL(string: address),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw APIError.transport("질문 음성 주소가 올바르지 않아요")
        }
        let request = URLRequest(url: url, timeoutInterval: 8)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              !data.isEmpty, data.count <= 8 * 1024 * 1024 else {
            throw APIError.transport("질문 음성을 다운로드하지 못했어요")
        }
        let player = try AVAudioPlayer(data: data)
        self.player = player
        player.delegate = self
        playbackResult = nil
        defer {
            player.stop()
            if self.player === player { self.player = nil }
        }
        guard player.prepareToPlay(), player.play() else {
            throw APIError.transport("질문 음성을 재생하지 못했어요")
        }
        let deadline = Date().addingTimeInterval(min(max(player.duration + 3, 3), 120))
        while playbackResult == nil {
            try await Task.sleep(for: .milliseconds(100))
            if Date() >= deadline { throw APIError.transport("질문 음성 재생 시간이 초과됐어요") }
        }
        try Task.checkCancellation()
        if playbackResult != true { throw APIError.transport("질문 음성 재생이 중단됐어요") }
    }

    private func speakLocal(_ text: String) async throws {
        try Task.checkCancellation()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        self.utterance = utterance
        synthesizer.speak(utterance)
        while self.utterance === utterance {
            try await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if self.player === player { playbackResult = flag }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            if self.player === player {
                playbackResult = false
                player.stop()
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor in
            if self.utterance.map(ObjectIdentifier.init) == identifier { self.utterance = nil }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor in
            if self.utterance.map(ObjectIdentifier.init) == identifier { self.utterance = nil }
        }
    }
}
