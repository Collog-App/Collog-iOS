//
//  AssetPlaceholder.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct AssetPlaceholder: View {
    private let width: CGFloat?
    private let height: CGFloat?
    private let cornerRadius: CGFloat

    init(size: CGFloat, cornerRadius: CGFloat = 0) {
        self.width = size
        self.height = size
        self.cornerRadius = cornerRadius
    }

    init(width: CGFloat? = nil, height: CGFloat? = nil, cornerRadius: CGFloat = 0) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    @ViewBuilder
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.assetPlaceholder)

        if let width {
            shape.frame(width: width, height: height)
        } else {
            shape.frame(maxWidth: .infinity).frame(height: height)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AssetPlaceholder(size: 24)
        AssetPlaceholder(size: 42, cornerRadius: 21)
        AssetPlaceholder(height: 73)
    }
    .padding()
}
