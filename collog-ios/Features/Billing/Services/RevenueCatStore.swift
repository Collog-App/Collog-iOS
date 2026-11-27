//
//  RevenueCatStore.swift
//  collog-ios
//

import Foundation
import RevenueCat

/// RevenueCat iOS SDK(5.104.0). 이 파일만 SDK 를 안다.
/// configure 는 앱 시작(didFinishLaunching)이 아니라, 로그인한 사용자가 정해지고 서버가 결제를 켠 뒤 처음 `identify` 때 한다.
/// `Purchases.shared` 는 configure 전에 부르면 앱이 멈추므로 늘 `Purchases.isConfigured` 를 먼저 본다.
final class RevenueCatStore: SubscriptionStore {
    /// 결제 약속 §1: entitlement `premium`, offering `default`, package `$rc_monthly`.
    static let entitlementId = "premium"
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

    func purchaseMonthly() async throws -> PurchaseOutcome {
        guard let package = try await monthlyPackage() else { throw ErrorCode.productNotAvailableForPurchaseError }
        do {
            return try await Purchases.shared.purchase(package: package).userCancelled ? .cancelled : .purchased
        } catch ErrorCode.purchaseCancelledError {
            return .cancelled
        } catch ErrorCode.paymentPendingError {
            return .pending
        } catch ErrorCode.productAlreadyPurchasedError {
            return .alreadyPurchased
        } catch ErrorCode.receiptAlreadyInUseError {
            // 같은 Apple ID 의 구독이 다른 콜록 계정에 묶여 있다. 복원하면 이 계정으로 옮겨진다
            return .alreadyPurchased
        }
    }

    func restore() async throws -> Bool {
        guard Purchases.isConfigured else { throw ErrorCode.configurationError }
        let customerInfo = try await Purchases.shared.restorePurchases()
        return customerInfo.entitlements[Self.entitlementId]?.isActive == true
    }

    private func monthlyPackage() async throws -> Package? {
        guard Purchases.isConfigured else { return nil }
        let offerings = try await Purchases.shared.offerings()
        let offering = offerings.all[Self.offeringId] ?? offerings.current
        return offering?.package(identifier: Self.packageId) ?? offering?.monthly
    }
}
