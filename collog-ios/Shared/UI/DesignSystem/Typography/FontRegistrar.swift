//
//  FontRegistrar.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import CoreText
import UIKit

enum FontRegistrar {
    static func registerIfNeeded() {
        for font in Pretendard.allCases where UIFont(name: font.rawValue, size: 12) == nil {
            guard let url = Bundle.main.url(forResource: font.fileName, withExtension: "otf") else {
                print("[Collog] 폰트 파일 없음: \(font.fileName).otf")
                continue
            }
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) {
                print("[Collog] 폰트 등록 실패: \(font.rawValue)")
            }
        }
    }
}
