//
//  RevenueCatStore.swift
//  collog-ios
//

import Foundation
import RevenueCat

/// RevenueCat iOS SDK(5.104.0). 이 파일만 SDK 를 안다.
/// configure 는 앱 시작(didFinishLaunching)이 아니라, 로그인한 사용자가 정해지고 서버가 결제를 켠 뒤 처음 `identify` 때 한다.
final class RevenueCatStore: SubscriptionStore {
    /// 결제 약속 §1: offering `default`, package `$rc_monthly`.
    static let offeringId = "default"
    static let packageId = "$rc_monthly"

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func identify(userId: String) async throws {
        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: apiKey, appUserID: userId)
        } else if Purchases.shared.appUserID != userId {
            _ = try await Purchases.shared.logIn(userId)
        }
    }

    func monthlyPrice() async throws -> StorePrice? {
        guard let product = try await monthlyPackage()?.storeProduct else { return nil }
        return StorePrice(
            amount: product.price,
            currencyCode: product.currencyCode,
            localizedString: product.localizedPriceString
        )
    }

    func purchaseMonthly() async throws -> Bool {
        guard let package = try await monthlyPackage() else { throw ErrorCode.productNotAvailableForPurchaseError }
        do {
            return try await !Purchases.shared.purchase(package: package).userCancelled
        } catch ErrorCode.purchaseCancelledError {
            return false
        }
    }

    func restore() async throws {
        _ = try await Purchases.shared.restorePurchases()
    }

    private func monthlyPackage() async throws -> Package? {
        let offerings = try await Purchases.shared.offerings()
        let offering = offerings.all[Self.offeringId] ?? offerings.current
        return offering?.package(identifier: Self.packageId) ?? offering?.monthly
    }
}
