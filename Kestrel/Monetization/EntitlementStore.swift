import Foundation
import StoreKit
import Observation

/// Free-tier limits. Pro adds *breadth and a steadier baseline* — never
/// certainty. Kept in one place so the gates are auditable.
enum FreeTierLimits {
    /// Stations a free user can watch at once.
    static let maxStations = 5
    /// Spike alerts a free user can set (Pro is unlimited).
    static let maxAlertsFree = 1
    /// Days of hourly history used for the baseline (free vs Pro).
    static let baselineDaysFree = 7
    static let baselineDaysPro = 30
}

/// StoreKit 2 entitlements for Kestrel Pro. Ported from the hardened
/// Hummingbird pattern: the debug unlock is fenced out of Release builds, so
/// shipping users can only unlock Pro through a real purchase.
@MainActor
@Observable
final class EntitlementStore {
    static let monthlyProductID = "com.avaresearch.kestrel.pro.monthly"
    static let yearlyProductID = "com.avaresearch.kestrel.pro.yearly"
    nonisolated static var allProductIDs: [String] { [monthlyProductID, yearlyProductID] }

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    var purchaseError: String?

    #if DEBUG
    var debugUnlocked = false
    #endif

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
        Task { await refreshEntitlements() }
    }

    var isPro: Bool {
        #if DEBUG
        return debugUnlocked || !purchasedProductIDs.isEmpty
        #else
        return !purchasedProductIDs.isEmpty
        #endif
    }

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyProductID } }
    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyProductID } }

    /// Percent the annual plan saves vs. twelve monthly renewals.
    var yearlySavingsPercent: Int? {
        guard let m = monthlyProduct, let y = yearlyProduct else { return nil }
        return Self.savingsPercent(monthly: m.price, yearly: y.price)
    }

    nonisolated static func savingsPercent(monthly: Decimal, yearly: Decimal) -> Int? {
        let annualized = monthly * 12
        guard annualized > 0, yearly < annualized else { return nil }
        let fraction = (annualized - yearly) / annualized
        return Int((fraction as NSDecimalNumber).doubleValue * 100 + 0.5)
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.allProductIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Couldn't load subscription options."
        }
    }

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase couldn't be completed."
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        purchasedProductIDs = owned
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
