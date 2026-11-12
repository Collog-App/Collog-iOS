//
//  ThirdPartyAIDisclosureView.swift
//  collog-ios
//

import SwiftUI

/// 외부 AI 서비스마다 무엇을 왜 보내는지 이름으로 밝힌다.
/// App Review 5.1.2(i)는 보내기 전에 받는 곳을 밝히라고 한다(1.1 (26) 반려: 「외부 AI」라고만 쓴 화면을 지적).
struct ThirdPartyAIDisclosureView: View {
    static let detailsURL = URL(string: "https://privacy.collog.live/consent.html")!
    static let privacyURL = URL(string: "https://privacy.collog.live")!

    private static let recipients: [(name: String, detail: String)] = [
        ("Deepgram", "통화 음성을 보내 대화를 글로 바꿔요"),
        ("Google Gemini", "대화 글(건강 이야기 포함)을 보내 건강 기록을 만들어요"),
        ("ElevenLabs", "오늘의 질문 문장을 보내 질문 목소리를 만들어요"),
    ]

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            Text("외부 AI로 보내는 정보")
                .body_02_semibold(.gray900)

            ForEach(Self.recipients, id: \.name) { recipient in
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text(recipient.name)
                        .body_03_medium(.gray900)
                    Text(recipient.detail)
                        .caption_01_medium(.gray700)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("이름·전화번호는 보내지 않지만 대화 중에 말한 내용은 들어갈 수 있어요. 해외 서버에서 처리될 수 있어요.")
                .caption_01_medium(.gray700)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.x4) {
                Button("자세히 보기 ›") { openURL(Self.detailsURL) }
                Button("개인정보처리방침 보기 ›") { openURL(Self.privacyURL) }
            }
            .pretendardStyle(.semiBold, 13, .gray800)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ThirdPartyAIDisclosureView()
        .padding()
}
