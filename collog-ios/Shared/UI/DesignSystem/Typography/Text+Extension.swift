//
//  Text+Extension.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

enum Pretendard: String, CaseIterable {
    case bold = "Pretendard-Bold"
    case semiBold = "Pretendard-SemiBold"
    case medium = "Pretendard-Medium"
    case regular = "Pretendard-Regular"

    var fileName: String { rawValue }
}

enum Typography {
    static let letterSpacingRatio: CGFloat = -0.025
    static let lineHeightRatio: CGFloat = 1.45
    static let fontLineHeightRatio: CGFloat = 1.2

    static func kerning(for size: CGFloat) -> CGFloat {
        size * letterSpacingRatio
    }

    static func lineSpacing(for size: CGFloat) -> CGFloat {
        size * (lineHeightRatio - fontLineHeightRatio)
    }
}

extension View {
    func pretendardStyle(_ weight: Pretendard, _ size: CGFloat, _ color: Color = .gray900) -> some View {
        font(.custom(weight.rawValue, size: size))
            .kerning(Typography.kerning(for: size))
            .foregroundStyle(color)
    }
}

extension Text {
    func headline_02(_ color: Color? = nil) -> some View { styled(.bold, 24, color) }

    func subtitle_01(_ color: Color? = nil) -> some View { styled(.semiBold, 20, color) }

    func subtitle_02(_ color: Color? = nil) -> some View { styled(.semiBold, 18, color) }

    func body_01_semibold(_ color: Color? = nil) -> some View { styled(.semiBold, 16, color) }

    func body_01_medium(_ color: Color? = nil) -> some View { styled(.medium, 16, color) }

    func body_01_regular(_ color: Color? = nil) -> some View { styled(.regular, 16, color) }

    func body_02_semibold(_ color: Color? = nil) -> some View { styled(.semiBold, 14, color) }

    func body_02_medium(_ color: Color? = nil) -> some View { styled(.medium, 14, color) }

    func body_02_regular(_ color: Color? = nil) -> some View { styled(.regular, 14, color) }

    func body_03_medium(_ color: Color? = nil) -> some View { styled(.medium, 13, color) }

    func caption_01_semibold(_ color: Color? = nil) -> some View { styled(.semiBold, 12, color) }

    func caption_01_medium(_ color: Color? = nil) -> some View { styled(.medium, 12, color) }

    func caption_01_regular(_ color: Color? = nil) -> some View { styled(.regular, 12, color) }

    func caption_02_semibold(_ color: Color? = nil) -> some View { styled(.semiBold, 10, color) }

    func caption_02_medium(_ color: Color? = nil) -> some View { styled(.medium, 10, color) }

    func caption_02_regular(_ color: Color? = nil) -> some View { styled(.regular, 10, color) }

    func pretendard(_ weight: Pretendard, _ size: CGFloat, _ color: Color? = nil) -> some View {
        styled(weight, size, color)
    }

    @ViewBuilder
    private func styled(_ weight: Pretendard, _ size: CGFloat, _ color: Color?) -> some View {
        let base = self
            .font(.custom(weight.rawValue, size: size))
            .kerning(Typography.kerning(for: size))
            .lineSpacing(Typography.lineSpacing(for: size))

        if let color {
            base.foregroundStyle(color)
        } else {
            base
        }
    }
}
