//
//  Icon.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct Icon: View {
    let name: String
    var size: CGFloat = IconSize.medium
    var weight: Font.Weight = .medium
    var color: Color = .gray800

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 0.82, weight: weight))
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

struct NotificationDot: View {
    var body: some View {
        Circle()
            .fill(Color.red500)
            .frame(width: 6, height: 6)
    }
}

#Preview {
    HStack(spacing: 16) {
        Icon(name: "bell")
        Icon(name: "phone.fill", color: .greenNormal)
        Icon(name: "chevron.right", size: IconSize.small, color: .gray600)
        NotificationDot()
    }
    .padding()
}
