//
//  CallRecordingIndicator.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/14/26.
//

import SwiftUI

struct CallRecordingIndicator: View {
    let isRecording: Bool

    var body: some View {
        Label("통화 녹음 중", systemImage: "record.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.x4)
            .padding(.vertical, Spacing.x2)
            .background(Color.red500, in: Capsule())
            .padding(.top, Spacing.x3)
            .opacity(isRecording ? 1 : 0)
            .accessibilityHidden(!isRecording)
            .accessibilityLabel("건강 기록을 위해 통화 음성을 녹음 중이에요")
    }
}
