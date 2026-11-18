//
//  Color+Extension.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

extension Color {
    static let gray00 = Color(hex: 0xFFFFFF)
    static let gray50 = Color(hex: 0xFAFBFC)
    static let gray100 = Color(hex: 0xF7F8F9)
    static let gray200 = Color(hex: 0xF3F4F5)
    static let gray300 = Color(hex: 0xEEEFF1)
    static let gray400 = Color(hex: 0xDCDEE3)
    static let gray500 = Color(hex: 0xD1D3D8)
    static let gray600 = Color(hex: 0xB0B3BA)
    static let gray700 = Color(hex: 0x868B94)
    static let gray800 = Color(hex: 0x555D6D)
    static let gray900 = Color(hex: 0x2A3038)
    static let gray1000 = Color(hex: 0x1A1C20)

    static let greenLight = Color(hex: 0xE9FAF3)
    static let greenLightActive = Color(hex: 0xBCF0D9)
    static let green100 = Color(hex: 0xF2FBF7)
    static let green200 = Color(hex: 0xCBEFE1)
    static let green300 = Color(hex: 0xA4E3CB)
    static let green400 = Color(hex: 0x7DD7B4)
    static let green500 = Color(hex: 0x55CB9E)
    static let greenNormal = Color(hex: 0x26CF85)
    static let greenDark = Color(hex: 0x1D9B64)
    static let green700 = Color(hex: 0x2C8F69)

    static let red100 = Color(hex: 0xFFF7F6)
    static let red300 = Color(hex: 0xFF9790)
    static let red400 = Color(hex: 0xFF685D)
    static let red500 = Color(hex: 0xFF382A)
    static let red600 = Color(hex: 0xF61000)
    static let red700 = Color(hex: 0xC30D00)

    static let blue100 = Color(hex: 0xE5F3FF)
    static let blue200 = Color(hex: 0xB3DBFF)
    static let blue500 = Color(hex: 0x1A94FF)
    static let blue600 = Color(hex: 0x007AE6)
    static let blue700 = Color(hex: 0x005FB3)

    static let orangeLight = Color(hex: 0xFFF4E6)
    static let orange600 = Color(hex: 0xFF5900)

    /// 부모(가족) 리포트를 볼 때의 액센트. 나 = 그린, 부모 = 주황.
    /// 큰 요소(아이콘·링·전화 버튼)는 parentAccent, 흰 글자·본문 글자는 parentAccentDark를 쓴다.
    static let parentAccent = Color(hex: 0xEF6C00)
    static let parentAccentDark = Color(hex: 0xAD4A00)
    static let parentAccentLight = Color(hex: 0xFFF1DC)
    static let parentAccentBorder = Color(hex: 0xFFD9A6)
    static let parentScreenBackground = Color(hex: 0xFFFCF7)

    static let disabledForeground = gray500

    static let kakaoYellow = Color(hex: 0xFAE100)
    static let kakaoLabel = Color(hex: 0x21232A)

    static let assetPlaceholder = Color(hex: 0xFF0000)
}

extension Color {
    nonisolated init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension LinearGradient {
    static let avatar = LinearGradient(
        colors: [Color(hex: 0xFFFBBF), Color(hex: 0x26CF85)],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}
