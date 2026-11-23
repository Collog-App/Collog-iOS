//
//  CardSurface.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct CardSurface: ViewModifier {
    @Environment(\.viewerAccent) private var accent
    var padding: CGFloat = Spacing.x4
    var cornerRadius: CGFloat = Radius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray00, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if let border = accent.cardBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(border, lineWidth: 1.5)
                }
            }
    }
}

extension View {
    func cardSurface(padding: CGFloat = Spacing.x4, cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(CardSurface(padding: padding, cornerRadius: cornerRadius))
    }
}

struct DividerLine: View {
    var axis: Axis = .horizontal

    var body: some View {
        Rectangle()
            .fill(Color.gray100)
            .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
    }
}
