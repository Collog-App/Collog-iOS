//
//  BadgeView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct BadgeView: View {
    let label: String
    var foregroundColor: Color = .blue600
    var backgroundColor: Color = .blue100

    var body: some View {
        Text(label)
            .caption_01_semibold(foregroundColor)
            .padding(.horizontal, Spacing.x2)
            .frame(height: 26)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: Radius.badgeMedium, style: .continuous))
    }
}

#Preview {
    HStack {
        BadgeView(label: "어머니")
        BadgeView(label: "아버지", foregroundColor: .greenDark, backgroundColor: .greenLight)
    }
    .padding()
}
