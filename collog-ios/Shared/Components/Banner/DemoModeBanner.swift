//
//  DemoModeBanner.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct DemoModeBanner: View {
    var onExit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.x2) {
            Text("DEMO")
                .caption_01_semibold(.gray800)

            Spacer(minLength: Spacing.x2)

            Button(action: onExit) {
                Text("로그인")
                    .caption_01_semibold(.greenDark)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.vertical, Spacing.x2)
        .frame(maxWidth: .infinity)
        .background(Color.orangeLight)
    }
}

#Preview {
    DemoModeBanner {}
}
