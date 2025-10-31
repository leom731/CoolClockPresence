// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  PurchaseManager.swift
//
//  Handles in-app purchases with StoreKit 2
//

#if os(macOS)
import StoreKit
import SwiftUI
import Combine

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var isLoading = false

    private let productID = "com.leomanderico.coolclockpresence.premium"
    private var updateListenerTask: Task<Void, Error>?

    // Premium status - check both purchase status and UserDefaults override for testing
    var isPremium: Bool {
        purchasedProductIDs.contains(productID) || UserDefaults.standard.bool(forKey: "isPremiumUnlocked")
    }

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        do {
            let loadedProducts = try await Product.products(for: [productID])
            products = loadedProducts
        } catch {
            print("Failed to load products: \(error)")
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase() async throws -> StoreKit.Transaction? {
        guard let product = products.first else {
            throw PurchaseError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }

    // MARK: - Update Purchased Products

    func updatePurchasedProducts() async {
        var newPurchasedIDs = Set<String>()

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                newPurchasedIDs.insert(transaction.productID)
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }

        purchasedProductIDs = newPurchasedIDs

        // Sync with UserDefaults for easier access
        UserDefaults.standard.set(!newPurchasedIDs.isEmpty, forKey: "isPremiumUnlocked")
    }

    // MARK: - Transaction Verification

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Listen for Transactions

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { @MainActor in
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
}

// MARK: - Purchase Errors

enum PurchaseError: Error, LocalizedError {
    case productNotFound
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .failedVerification:
            return "Transaction verification failed"
        }
    }
}
#endif
