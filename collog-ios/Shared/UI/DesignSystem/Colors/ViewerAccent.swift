//
//  ViewerAccent.swift
//  collog-ios
//

import SwiftUI

/// 리포트·타임라인에서 지금 누구의 기록을 보는지에 따라 바뀌는 색 세트.
/// 나 = 브랜드 그린, 가족(부모) = 주황. 색은 보조 신호이고 이름·태그·제목 문구가 실제 구분을 맡는다.
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
    /// 카드 테두리. 나는 없음
    let cardBorder: Color?

    static let me = ViewerAccent(
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

    static let parent = ViewerAccent(
        accent: .parentAccent,
        fab: .parentAccent,
        tabLabel: .parentAccentDark,
        text: .parentAccentDark,
        light: .parentAccentLight,
        border: .parentAccentBorder,
        background: .parentScreenBackground,
        tabBorder: .parentAccentBorder,
        cardBorder: .parentAccentBorder
    )
}

private struct ViewerAccentKey: EnvironmentKey {
    static let defaultValue = ViewerAccent.me
}

extension EnvironmentValues {
    var viewerAccent: ViewerAccent {
        get { self[ViewerAccentKey.self] }
        set { self[ViewerAccentKey.self] = newValue }
    }
}
