//
//  ConditionNoteField.swift
//  collog-ios
//

import SwiftUI

/// 질환 목록 아래 자유 입력 칸(서버 `concerns`, 최대 500자). 목록에 없는 질환도 직접 적을 수 있게 한다(11-15 기획 피드백).
/// 안드로이드 `CONCERNS_LABEL`·`CONCERNS_PLACEHOLDER`·`CONCERNS_CAPTION`과 같은 문구.
struct ConditionNoteField: View {
    static let limit = 500

    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            HStack(spacing: Spacing.x1) {
                Text("목록에 없는 질환이나 걱정되는 부분")
                    .body_02_medium(.gray900)
                Text("선택")
                    .caption_01_medium(.gray700)
            }

            TextField("예: 관절염이 있어요. 요즘 잠을 잘 못 자요.", text: $text, axis: .vertical)
                .lineLimit(3...6)
                .pretendardStyle(.medium, 15, .gray900)
                .padding(Spacing.x4)
                .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.gray200, lineWidth: 1)
                }
                .onChange(of: text) { _, newValue in
                    if newValue.count > Self.limit { text = String(newValue.prefix(Self.limit)) }
                }

            HStack(alignment: .top) {
                Text("적은 내용은 가족도 건강 프로필에서 볼 수 있어요.")
                    .caption_01_medium(.gray700)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.x2)
                Text("\(text.count)/\(Self.limit)")
                    .caption_01_medium(.gray700)
            }
        }
    }
}

#Preview {
    ConditionNoteField(text: .constant(""))
        .padding()
}
