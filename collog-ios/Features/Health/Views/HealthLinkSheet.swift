//
//  HealthLinkSheet.swift
//  collog-ios
//

import SwiftUI

/// 건강 앱 연결 흐름(피그마 없음): 동의 문서 → 건강 앱 권한 창 → 연결 → 동기화 → 「연결됐어요」.
/// 설정·홈·리포트가 `HealthLink.present()`로 연다. 어르신이 쓰기 쉽게 큰 글씨와 버튼 하나로 둔다.
struct HealthLinkSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var confirmsDisconnect = false

    private var link: HealthLink { environment.health }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.x5)
            .padding(.top, Spacing.x8)
            .padding(.bottom, Spacing.x8)
        }
        .background(Color.gray50)
        .presentationDragIndicator(.visible)
        .task { await link.prepare(using: environment) }
        .alert("건강 앱 연결을 끊을까요?", isPresented: $confirmsDisconnect) {
            Button("취소", role: .cancel) {}
            Button("연결 끊기", role: .destructive) {
                Task { await link.disconnect(using: environment) }
            }
        } message: {
            Text("서버에 저장된 건강 요약이 바로 지워지고, 가족 리포트에서도 보이지 않아요.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch link.step {
        case .loading:
            waiting(nil)
        case .connecting:
            waiting("연결하고 있어요")
        case .notReady:
            message("건강 앱 연결을 준비하고 있어요", "조금만 기다려 주세요. 준비가 끝나면 여기에서 연결할 수 있어요.")
            primaryButton("확인") { link.isPresented = false }
        case .unavailable:
            message("이 휴대폰에서는 건강 앱을 연결할 수 없어요", "건강 앱을 쓸 수 있는 iPhone에서 연결해 주세요.")
            primaryButton("확인") { link.isPresented = false }
        case let .consent(document, notice):
            consent(document, notice: notice)
        case let .linked(justConnected, lastSyncedDay, needsPermission):
            linked(justConnected: justConnected, lastSyncedDay: lastSyncedDay, needsPermission: needsPermission)
        case let .failed(text):
            message("연결하지 못했어요", text)
            primaryButton("다시 시도") { Task { await link.prepare(using: environment) } }
        }
    }

    /// 서버 동의 문서를 그대로(제목·줄 목록) 큰 글씨로 보이고, 「동의하고 연결」 한 버튼.
    @ViewBuilder
    private func consent(_ document: HealthLinkDocument, notice: String?) -> some View {
        Text(document.title)
            .headline_02(.gray900)
        if let notice {
            Text(notice)
                .body_01_medium(.orange600)
                .fixedSize(horizontal: false, vertical: true)
        }
        VStack(alignment: .leading, spacing: Spacing.x3) {
            ForEach(Array(document.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                    Text("•")
                        .pretendard(.medium, 17, .gray800)
                    Text(item)
                        .pretendard(.medium, 17, .gray800)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        primaryButton("동의하고 연결") {
            Haptics.press()
            Task { await link.connect(document, using: environment) }
        }
    }

    @ViewBuilder
    private func linked(justConnected: Bool, lastSyncedDay: String?, needsPermission: Bool) -> some View {
        message(
            justConnected ? "연결됐어요" : "건강 앱이 연결돼 있어요",
            "가족 리포트의 「생활 기록」에서 수면·걸음 변화를 함께 볼 수 있어요."
        )
        if let day = lastSyncedDay.flatMap(HealthDailyCalculator.day(from:)) {
            Text("마지막으로 보낸 날: \(LifeRecord.dayText(day))")
                .body_02_regular(.gray700)
        }
        if needsPermission {
            Text("이 휴대폰에서는 아직 건강 앱 읽기를 허용하지 않아 기록을 보내지 못하고 있어요.")
                .body_01_medium(.red500)
                .fixedSize(horizontal: false, vertical: true)
            primaryButton("건강 앱 읽기 허용") { Task { await link.regrant(using: environment) } }
        } else {
            if lastSyncedDay == nil {
                Text("아직 보낸 기록이 없어요. 기록이 있는데도 보이지 않으면 건강 앱에서 콜록의 읽기 권한이 켜져 있는지 확인해 주세요.")
                    .body_02_medium(.gray800)
                    .fixedSize(horizontal: false, vertical: true)
            }
            primaryButton("확인") { link.isPresented = false }
        }
        Button("연결 끊기") { confirmsDisconnect = true }
            .pretendardStyle(.semiBold, 14, .red500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.x2)
    }

    private func waiting(_ text: String?) -> some View {
        VStack(spacing: Spacing.x3) {
            ProgressView()
            if let text {
                Text(text)
                    .pretendard(.medium, 17, .gray800)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    @ViewBuilder
    private func message(_ title: String, _ body: String) -> some View {
        Text(title)
            .headline_02(.gray900)
            .fixedSize(horizontal: false, vertical: true)
        Text(body)
            .pretendard(.medium, 17, .gray800)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .body_01_semibold(.gray00)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.x2)
    }
}
