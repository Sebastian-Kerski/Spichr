//
//  ShoppingItemRow.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import CoreData

struct ShoppingItemRow: View {
    
    let item: FoodItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox Icon
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.blue)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Name & Quantity
                    HStack {
                        Text(item.unwrappedName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if !item.unwrappedQuantity.isEmpty {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(item.unwrappedQuantity)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Store Info
                    if !item.unwrappedStore.isEmpty {
                        Label(item.unwrappedStore, systemImage: "building.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    List {
        ShoppingItemRow(
            item: {
                let item = FoodItem(context: PersistenceController.preview.viewContext)
                item.name = "Milk"
                item.quantity = "1L"
                item.store = "REWE"
                item.isInStock = false
                return item
            }(),
            onTap: {}
        )
        
        ShoppingItemRow(
            item: {
                let item = FoodItem(context: PersistenceController.preview.viewContext)
                item.name = "Bread"
                item.quantity = "1 loaf"
                item.store = "Aldi"
                item.isInStock = false
                return item
            }(),
            onTap: {}
        )
        
        ShoppingItemRow(
            item: {
                let item = FoodItem(context: PersistenceController.preview.viewContext)
                item.name = "Apples"
                item.quantity = "1kg"
                item.isInStock = false
                return item
            }(),
            onTap: {}
        )
    }
}
