//
//  TodoListCardView.swift
//  collog-ios
//

import SwiftUI

/// 홈의 개인용 "오늘 할 일" 카드
struct TodoListCardView: View {
    @Environment(AppEnvironment.self) private var environment
    let model: TodoListModel

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("오늘 할 일")
                .body_01_semibold(.gray900)

            list

            if let error = model.actionError {
                Text(error)
                    .caption_01_medium(.red500)
            }

            HStack(spacing: Spacing.x2) {
                TextField("할 일을 직접 추가해 보세요", text: $model.draft)
                    .pretendardStyle(.medium, 14)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .padding(.horizontal, Spacing.x3)
                    .frame(height: 40)
                    .background(Color.gray100, in: RoundedRectangle(cornerRadius: Radius.btnSmall))

                Button(action: add) {
                    Text("추가")
                        .body_02_semibold(model.canAdd ? .greenDark : .gray600)
                        .padding(.horizontal, Spacing.x2)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
                .disabled(!model.canAdd)
            }

            Text("추천 활동은 등록한 질환과 걸음 수를 보고 골라요. 의료 조언이 아니에요.")
                .caption_01_regular(.gray700)
        }
        .cardSurface()
    }

    @ViewBuilder
    private var list: some View {
        if model.loadFailed {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("할 일을 불러오지 못했어요")
                    .body_02_medium(.gray800)
                Button {
                    Task { await model.load(using: environment) }
                } label: {
                    Text("다시 시도").body_02_semibold(.greenDark)
                }
                .buttonStyle(.plain)
            }
        } else if model.items.isEmpty {
            Text(model.isLoading ? " " : "오늘 할 일이 없어요")
                .body_02_medium(.gray700)
        } else {
            VStack(alignment: .leading, spacing: Spacing.x3) {
                ForEach(model.items) { item in row(item) }
            }
        }
    }

    private func row(_ item: TodoDTO) -> some View {
        HStack(spacing: Spacing.x3) {
            Button {
                Haptics.press()
                Task { await model.toggle(item, using: environment) }
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(item.done ? Color.greenNormal : Color.gray500)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.done ? "완료 취소" : "완료")

            Text(item.title)
                .body_02_medium(item.done ? .gray600 : .gray900)
                .strikethrough(item.done)
                .frame(maxWidth: .infinity, alignment: .leading)

            if item.source == .suggested {
                Text("추천")
                    .caption_01_semibold(.green700)
                    .padding(.horizontal, Spacing.x2)
                    .padding(.vertical, 2)
                    .background(Color.greenLight, in: Capsule())
            }

            Button {
                Task { await model.delete(item, using: environment) }
            } label: {
                Icon(name: "xmark", size: 14, color: .gray600)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("삭제")
        }
    }

    private func add() {
        guard model.canAdd else { return }
        Task { await model.add(using: environment) }
    }
}
