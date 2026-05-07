//
//  ProManager.swift
//  Spichr
//

import StoreKit
import SwiftUI
import Observation

@Observable
final class ProManager {

    static let shared = ProManager()

    // com.de.SkerskiDev.FoodGuard.pro
    private static let proProductID = "com.de.SkerskiDev.FoodGuard.pro"

    private(set) var isPro: Bool = true
    private(set) var product: Product?
    private(set) var isLoading: Bool = false

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await fetchProducts() }
        Task { await refreshPurchaseStatus() }
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Products

    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
        } catch {
            // Silently ignore — StoreKit not available in simulator without configuration
        }
    }

    // MARK: - Purchase

    func purchase() async throws {
        guard let product else { return }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchaseStatus()
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
        } catch {
            // Ignore
        }
    }

    // MARK: - Status

    func refreshPurchaseStatus() async {
        await updatePurchaseStatus()
    }

    private func updatePurchaseStatus() async {
        // All features are free — isPro is always true
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self?.updatePurchaseStatus()
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }

    enum StoreError: Error { case failedVerification }
}

// MARK: - Pro Gate View

struct ProGateView<Content: View>: View {
    @Environment(ProManager.self) private var proManager
    let feature: String
    let content: () -> Content

    @State private var showUpgrade = false

    var body: some View {
        if proManager.isPro {
            content()
        } else {
            Button {
                showUpgrade = true
            } label: {
                Label(feature, systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }
            .sheet(isPresented: $showUpgrade) {
                ProUpgradeView()
            }
        }
    }
}

// MARK: - Upgrade Sheet

struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProManager.self) private var proManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.yellow)
                        .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text(LocalizedStringKey("pro_title"))
                            .font(.title.bold())
                        Text(LocalizedStringKey("pro_subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        ProFeatureRow(icon: "fork.knife.circle.fill", color: .orange, key: "pro_feature_recipes")
                        ProFeatureRow(icon: "clock.arrow.circlepath", color: .blue, key: "pro_feature_activity")
                    }
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        if proManager.isLoading {
                            ProgressView()
                        } else if let product = proManager.product {
                            Button {
                                Task { try? await proManager.purchase() }
                            } label: {
                                Text(String(format: NSLocalizedString("pro_buy_button", comment: ""), product.displayPrice))
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal)
                        }

                        Button(LocalizedStringKey("pro_restore")) {
                            Task { await proManager.restorePurchases() }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 32)
                }
            }
            .navigationTitle(LocalizedStringKey("pro_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("action_close")) { dismiss() }
                }
            }
        }
    }
}

private struct ProFeatureRow: View {
    let icon: String
    let color: Color
    let key: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(key + "_title"))
                    .font(.headline)
                Text(LocalizedStringKey(key + "_desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
