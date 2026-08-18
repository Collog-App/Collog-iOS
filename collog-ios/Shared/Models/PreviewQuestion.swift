//
//  PreviewQuestion.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct PreviewQuestion: Identifiable {
    let id = UUID()
    let text: String
}

extension PreviewQuestion {
    static let samples: [PreviewQuestion] = [
        PreviewQuestion(text: "요즘 밤에 주무실 때 불편한 점은 없으신가요?"),
        PreviewQuestion(text: "이번 주에 산책이나 가벼운 외출은 하셨나요?"),
        PreviewQuestion(text: "이번 주에 산책이나 가벼운 외출은 하셨나요?"),
        PreviewQuestion(text: "이번 주에 산책이나 가벼운 외출은 하셨나요?")
    ]
}
