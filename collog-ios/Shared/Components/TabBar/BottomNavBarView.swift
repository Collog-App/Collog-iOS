//
//  BottomNavBarView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct BottomNavBarView: View {
    @Binding var selection: MainTab
    let launcher: CallLauncherModel
    var onLaunch: (FamilyContact) -> Void
    var onReselect: (MainTab) -> Void = { _ in }

    static let barHeight: CGFloat = 64
    static let buttonLift: CGFloat = 14
    static let anchorInset: CGFloat = barHeight / 2 + buttonLift

    @State private var isPressing = false

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.report)
                Color.clear
                    .frame(maxWidth: .infinity)
                tabButton(.timeline)
                tabButton(.settings)
            }
            .padding(.horizontal, Spacing.x3)
            .frame(height: Self.barHeight)
            .frame(maxWidth: .infinity)
            .background(alignment: .top) {
                Rectangle()
                    .fill(.thinMaterial)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay {
                        Color.gray00.opacity(0.72)
                            .ignoresSafeArea(edges: .bottom)
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.gray200)
                            .frame(height: 1)
                    }
            }
            .offset(y: launcher.isPresented ? Self.barHeight + Spacing.x8 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.9), value: launcher.isPresented)

            callButton

            if launcher.showsHoldHint {
                Text("길게 눌러보세요")
                    .body_03_medium(.gray00)
                    .padding(.horizontal, Spacing.x4)
                    .padding(.vertical, Spacing.x2)
                    .background(Color.gray900, in: Capsule())
                    .offset(y: -86)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(height: Self.barHeight)
        .frame(maxWidth: .infinity)
    }

    private func tabButton(_ tab: MainTab) -> some View {
        Button {
            launcher.dismiss()
            if selection == tab {
                onReselect(tab)
            } else {
                selection = tab
            }
            Haptics.press()
        } label: {
            VStack(spacing: 2) {
                Icon(
                    name: tab.symbol,
                    size: IconSize.medium,
                    color: selection == tab ? .greenNormal : .gray600
                )
                Text(tab.title)
                    .caption_01_medium(selection == tab ? .greenNormal : .gray600)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var callButton: some View {
        ZStack {
            Circle()
                .fill(Color.gray50)
                .frame(width: 68, height: 68)

            Circle()
                .fill(Color.greenNormal)
                .frame(width: 58, height: 58)
                .shadow(
                    color: Color.greenNormal.opacity(launcher.isPresented ? 0.45 : 0.28),
                    radius: launcher.isPresented ? 22 : 12,
                    y: 6
                )

            Icon(name: "phone.fill", size: 26, weight: .semibold, color: .gray00)
        }
        .scaleEffect(scale)
        .frame(maxWidth: .infinity)
        .offset(y: -Self.buttonLift)
        .contentShape(Circle())
        .gesture(pressGesture)
        .accessibilityLabel("가족에게 전화")
        .accessibilityHint(
            "길게 누른 채 원하는 가족으로 "
            + "손가락을 옮긴 뒤 떼면 전화를 걸어요"
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
    }

    private var scale: CGFloat {
        if launcher.isPresented { return 1.1 }
        return isPressing ? 0.94 : 1
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressing {
                    isPressing = true
                    launcher.pressBegan()
                }
                launcher.dragChanged(value.translation)
            }
            .onEnded { _ in
                isPressing = false
                if let contact = launcher.pressEnded() {
                    onLaunch(contact)
                }
            }
    }
}

#Preview {
    @Previewable @State var selection = MainTab.home
    let launcher = CallLauncherModel()

    return VStack {
        Spacer()
        BottomNavBarView(selection: $selection, launcher: launcher, onLaunch: { _ in })
    }
    .background(Color.gray50)
}
