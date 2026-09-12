//
//  CollogApp.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI
import UIKit
import UserNotifications

@main
struct CollogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appDelegate.environment)
                .environment(appDelegate.callCenter)
                .preferredColorScheme(.light)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let environment = AppEnvironment()
    private(set) lazy var callCenter = CallCenter(environment: environment)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FontRegistrar.registerIfNeeded()
        NavigationBarAppearance.apply()
        UNUserNotificationCenter.current().delegate = self
        callCenter.start()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        callCenter.setRemoteNotificationToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        callCenter.setRemoteNotificationError(error.localizedDescription)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await receiveReportNotification(notification, openReport: false)
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await receiveReportNotification(response.notification, openReport: true)
    }

    private nonisolated func receiveReportNotification(_ notification: UNNotification, openReport: Bool) async {
        guard let report = notification.request.content.userInfo["report"] as? [String: Any],
              let callId = report["callId"] as? String, !callId.isEmpty else { return }
        let title = notification.request.content.title
        let message = notification.request.content.body
        await MainActor.run {
            environment.receiveReportNotification(
                callId: callId,
                title: title,
                message: message,
                openReport: openReport
            )
        }
    }
}
