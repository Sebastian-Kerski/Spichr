//
//  TipJarService.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Foundation
import StoreKit

/// Service for handling voluntary tips/donations
@Observable
final class TipJarService {
    
    // MARK: - Singleton
    
    static let shared = TipJarService()
    
    // MARK: - Properties
    
    private(set) var tips: [Tip] = []
    private(set) var isLoading = false
    private(set) var purchaseError: TipError?
    
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadTips()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Tips
    
    @MainActor
    func loadTips() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch products from App Store
            let productIDs: Set<String> = [
                "com.de.SkerskiDev.Spichr.tip.small",
                "com.de.SkerskiDev.Spichr.tip.medium",
                "com.de.SkerskiDev.Spichr.tip.large"
            ]
            
            let products = try await Product.products(for: productIDs)
            
            // Sort by price
            let sortedProducts = products.sorted { $0.price < $1.price }
            
            // Map to Tip model
            tips = sortedProducts.enumerated().map { index, product in
                Tip(
                    id: product.id,
                    product: product,
                    emoji: Self.emoji(for: index),
                    title: Self.title(for: index),
                    description: Self.description(for: index)
                )
            }
        } catch {
            purchaseError = .loadFailed(error)
            print("Failed to load tips: \(error)")
        }
    }
    
    // MARK: - Purchase Tip
    
    @MainActor
    func purchase(_ tip: Tip) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await tip.product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)
                
                // Show thank you message
                await showThankYou(for: tip)
                
                // Finish the transaction
                await transaction.finish()
                
            case .userCancelled:
                // User cancelled, no error needed
                break
                
            case .pending:
                purchaseError = .pending
                
            @unknown default:
                purchaseError = .unknown
            }
        } catch {
            purchaseError = .purchaseFailed(error)
            print("Purchase failed: \(error)")
        }
    }
    
    // MARK: - Transaction Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TipError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerifiedStatic(result)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // Static version for use in detached tasks
    private static func checkVerifiedStatic<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TipError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Thank You
    
    @MainActor
    private func showThankYou(for tip: Tip) async {
        // This will trigger haptic feedback and show a toast
        // You can implement this in your UI layer
        print("🎉 Thank you for the \(tip.title)!")
    }
    
    // MARK: - Helper Methods
    
    private static func emoji(for index: Int) -> String {
        switch index {
        case 0: return "☕️"
        case 1: return "🙏"
        case 2: return "🎉"
        default: return "❤️"
        }
    }
    
    private static func title(for index: Int) -> String {
        switch index {
        case 0: return NSLocalizedString("tip_small_title", comment: "Small Tip")
        case 1: return NSLocalizedString("tip_medium_title", comment: "Medium Tip")
        case 2: return NSLocalizedString("tip_large_title", comment: "Large Tip")
        default: return "Tip"
        }
    }
    
    private static func description(for index: Int) -> String {
        switch index {
        case 0: return NSLocalizedString("tip_small_desc", comment: "Buy me a coffee")
        case 1: return NSLocalizedString("tip_medium_desc", comment: "Support development")
        case 2: return NSLocalizedString("tip_large_desc", comment: "You're awesome!")
        default: return ""
        }
    }
}

// MARK: - Tip Model

struct Tip: Identifiable {
    let id: String
    let product: Product
    let emoji: String
    let title: String
    let description: String
    
    var displayPrice: String {
        product.displayPrice
    }
}

// MARK: - TipError

enum TipError: LocalizedError {
    case loadFailed(Error)
    case purchaseFailed(Error)
    case verificationFailed
    case pending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load tips: \(error.localizedDescription)"
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .verificationFailed:
            return "Transaction verification failed"
        case .pending:
            return "Purchase is pending approval"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
