//
//  TipJarView.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import StoreKit

struct TipJarView: View {
    
    @StateObject private var store = TipJarStore()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.red.gradient)
                        
                        Text("support_developer_title")
                            .font(.title2.bold())
                        
                        Text("tip_jar_message")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Tips
                    VStack(spacing: 16) {
                        ForEach(store.products) { product in
                            TipButton(product: product) {
                                Task {
                                    await store.purchase(product)
                                }
                            }
                            .disabled(store.isPurchasing)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Thank you message
                    if !store.products.isEmpty {
                        VStack(spacing: 8) {
                            Text("contribution_message")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("thank_you_support")
                                .font(.footnote.bold())
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                }
                .padding(.bottom, 32)
            }
            .navigationTitle(LocalizedStringKey("tip_jar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("action_close")) {
                        dismiss()
                    }
                }
            }
            .alert(LocalizedStringKey("tip_jar_thank_you_title"), isPresented: $store.showThankYou) {
                Button(LocalizedStringKey("ok")) {
                    dismiss()
                }
            } message: {
                Text("support_means_world")
            }
            .overlay {
                if store.isPurchasing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
}

// MARK: - Tip Button

struct TipButton: View {
    let product: Product
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Emoji
                Text(product.emoji)
                    .font(.system(size: 40))
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Price
                Text(product.localizedPrice)
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    TipJarView()
}
