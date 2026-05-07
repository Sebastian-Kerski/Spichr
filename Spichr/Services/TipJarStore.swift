//
//  TipJarStore.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import StoreKit
import os
import SwiftUI
import Combine

/// Manages tip jar purchases using StoreKit 2
@MainActor
final class TipJarStore: ObservableObject {
    private let logger = Logger(subsystem: "com.de.SkerskiDev.Spichr", category: "TipJar")
    
    // MARK: - Published Properties
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPurchasing = false
    @Published var showThankYou = false
    
    // MARK: - Product IDs
    
    private let productIDs: [String] = [
        "com.sekidev.Spichr.tip.small",   // 0.99€
        "com.de.SkerskiDev.Spichr.tip.medium",  // 4.99€
        "com.de.SkerskiDev.Spichr.tip.large"    // 9.99€
    ]
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadProducts()
        }
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        do {
            // Fetch products from App Store
            let storeProducts = try await Product.products(for: productIDs)
            
            // Sort by price (ascending)
            products = storeProducts.sorted { $0.price < $1.price }
            
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)
                
                // Transaction is verified
                showThankYou = true
                
                // Finish the transaction
                await transaction.finish()
                
            case .userCancelled:
                // User cancelled, do nothing
                break
                
            case .pending:
                // Purchase is pending (Ask to Buy)
                break
                
            @unknown default:
                break
            }
            
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Transaction Verification
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TipJarError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Restore Purchases (für Consumables nicht nötig, aber für Konsistenz)
    
    func restorePurchases() async {
        // Consumables können nicht restored werden
        // Aber wir können checken ob es aktive Transaktionen gibt
        do {
            try await AppStore.sync()
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - TipJarError

enum TipJarError: Error {
    case failedVerification
}

// MARK: - Product Extension for UI

extension Product {
    
    var emoji: String {
        switch id {
        case "com.sekidev.Spichr.tip.small":
            return "☕️"
        case "com.de.SkerskiDev.Spichr.tip.medium":
            return "🙏"
        case "com.de.SkerskiDev.Spichr.tip.large":
            return "🎉"
        default:
            return "💝"
        }
    }
    
    var localizedPrice: String {
        displayPrice
    }
}
