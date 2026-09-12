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
    private var socket: URLSessionWebSocketTask?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(
        _ questions: [APIQuestion], callId: String, api: CollogAPI, onEvent: @escaping (String) -> Void
    ) {
        stop()
        let generation = generation
        task = Task {
            defer {
                if self.generation == generation { task = nil }
            }
            for question in questions {
                guard !Task.isCancelled, self.generation == generation else { return }
                do {
                    if question.usesRemoteAudio || question.ttsMode == "ELEVENLABS_DIRECT" {
                        do {
                            if question.ttsMode == "ELEVENLABS_DIRECT" {
                                let token = try await api.questionTtsToken(callId: callId, questionId: question.id)
                                try Task.checkCancellation()
                                let audio = try await receiveAudio(text: question.text, token: token)
                                try await playAudio(audio)
                            } else {
                                try await playRemote(question)
                            }
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
                    if !Task.isCancelled { onEvent(error.localizedDescription) }
                    return
                }
            }
        }
    }

    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
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
        try await playAudio(data)
    }

    private func receiveAudio(text: String, token: QuestionTtsToken) async throws -> Data {
        guard !token.token.isEmpty, !token.voiceId.isEmpty,
              token.voiceId.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
              token.outputFormat.hasPrefix("mp3_") else {
            throw APIError.transport("질문 음성 설정을 확인해주세요")
        }
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "api.elevenlabs.io"
        components.path = "/v1/text-to-speech/\(token.voiceId)/stream-input"
        components.queryItems = [
            URLQueryItem(name: "single_use_token", value: token.token),
            URLQueryItem(name: "model_id", value: token.modelId),
            URLQueryItem(name: "output_format", value: token.outputFormat),
            URLQueryItem(name: "auto_mode", value: "true")
        ]
        if token.modelId != "eleven_multilingual_v2" {
            components.queryItems?.append(URLQueryItem(name: "language_code", value: "ko"))
        }
        guard let url = components.url else { throw APIError.transport("질문 음성 주소가 올바르지 않아요") }
        let socket = URLSession.shared.webSocketTask(with: url)
        socket.maximumMessageSize = 8 * 1024 * 1024
        self.socket = socket
        socket.resume()
        let timeout = Task {
            try await Task.sleep(for: .seconds(15))
            socket.cancel(with: .goingAway, reason: nil)
        }
        defer {
            timeout.cancel()
            socket.cancel(with: .normalClosure, reason: nil)
            if self.socket === socket { self.socket = nil }
        }
        for input in [" ", text + " ", ""] {
            let data = try JSONEncoder().encode(TtsInput(text: input))
            try await socket.send(.string(String(decoding: data, as: UTF8.self)))
        }
        var audio = Data()
        while true {
            try Task.checkCancellation()
            let message = try await socket.receive()
            let data: Data
            switch message {
            case .data(let value): data = value
            case .string(let value): data = Data(value.utf8)
            @unknown default: throw APIError.transport("질문 음성 응답을 이해하지 못했어요")
            }
            let chunk = try JSONDecoder().decode(TtsOutput.self, from: data)
            if chunk.error != nil { throw APIError.transport("질문 음성을 생성하지 못했어요") }
            if let encoded = chunk.audio, !encoded.isEmpty {
                guard let bytes = Data(base64Encoded: encoded), audio.count + bytes.count <= 8 * 1024 * 1024 else {
                    throw APIError.transport("질문 음성 데이터가 올바르지 않아요")
                }
                audio.append(bytes)
            }
            if chunk.isFinal == true {
                guard !audio.isEmpty else { throw APIError.transport("질문 음성이 비어 있어요") }
                try Task.checkCancellation()
                return audio
            }
        }
    }

    private struct TtsInput: Encodable {
        let text: String
    }

    private struct TtsOutput: Decodable {
        let audio: String?
        let isFinal: Bool?
        let error: String?

        enum CodingKeys: String, CodingKey {
            case audio, error, isFinal
            case snakeCaseFinal = "is_final"
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            audio = try values.decodeIfPresent(String.self, forKey: .audio)
            error = try values.decodeIfPresent(String.self, forKey: .error)
            isFinal = try values.decodeIfPresent(Bool.self, forKey: .isFinal)
                ?? values.decodeIfPresent(Bool.self, forKey: .snakeCaseFinal)
        }
    }

    private func playAudio(_ data: Data) async throws {
        try Task.checkCancellation()
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
        guard let voice = AVSpeechSynthesisVoice(language: "ko-KR") else {
            throw APIError.transport("iPhone에 한국어 음성을 설치한 뒤 다시 시도해주세요")
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        self.utterance = utterance
        synthesizer.speak(utterance)
        let deadline = Date().addingTimeInterval(120)
        while self.utterance === utterance {
            try await Task.sleep(for: .milliseconds(100))
            if Date() >= deadline {
                synthesizer.stopSpeaking(at: .immediate)
                self.utterance = nil
                throw APIError.transport("기기 음성 재생 시간이 초과됐어요")
            }
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
