//
//  ViewerAccent.swift
//  collog-ios
//

import SwiftUI

/// 리포트·타임라인에서 지금 누구의 기록을 보는지에 따라 바뀌는 색 세트.
/// 가족(기본 흐름) = 브랜드 그린 그대로, 「나」의 기록 = 주황. 색은 보조 신호이고 이름·태그·제목 문구가 실제 구분을 맡는다.
struct ViewerAccent: Equatable {
    /// 아이콘·링·아바타 채움 같은 큰 요소
    let accent: Color
    /// 가운데 전화 버튼
    let fab: Color
    /// 탭바 선택 글자
    let tabLabel: Color
    /// 버튼 글자·태그 배경처럼 흰색 또는 옅은 배경 위에 얹는 진한 톤
    let text: Color
    /// 칩·버튼 배경
    let light: Color
    let border: Color
    let background: Color
    let tabBorder: Color
    /// 카드 테두리. 가족(기본)은 없음
    let cardBorder: Color?

    /// 가족을 볼 때(기본). 기존 앱 색 그대로
    static let family = ViewerAccent(
        accent: .greenNormal,
        fab: .greenNormal,
        tabLabel: .greenNormal,
        text: .greenDark,
        light: .greenLight,
        border: .greenLightActive,
        background: .gray50,
        tabBorder: .gray200,
        cardBorder: nil
    )

    /// 내 기록을 볼 때
    static let mine = ViewerAccent(
        accent: .selfAccent,
        fab: .selfAccent,
        tabLabel: .selfAccentDark,
        text: .selfAccentDark,
        light: .selfAccentLight,
        border: .selfAccentBorder,
        background: .selfScreenBackground,
        tabBorder: .selfAccentBorder,
        cardBorder: .selfAccentBorder
    )
}

private struct ViewerAccentKey: EnvironmentKey {
    static let defaultValue = ViewerAccent.family
}

extension EnvironmentValues {
    var viewerAccent: ViewerAccent {
        get { self[ViewerAccentKey.self] }
        set { self[ViewerAccentKey.self] = newValue }
    }
}
