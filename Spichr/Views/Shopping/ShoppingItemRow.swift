//
//  ShoppingItemRow.swift
//  Spichr
//

import SwiftUI
import CoreData

struct ShoppingItemRow: View {

    let item: FoodItem
    let shoppingMode: Bool
    let onTap: () -> Void
    let onCheck: (() -> Void)?

    init(item: FoodItem, shoppingMode: Bool = false, onTap: @escaping () -> Void, onCheck: (() -> Void)? = nil) {
        self.item = item
        self.shoppingMode = shoppingMode
        self.onTap = onTap
        self.onCheck = onCheck
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox (shopping mode) or category emoji
            if shoppingMode {
                Button {
                    onCheck?()
                } label: {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            } else {
                Text(item.itemCategory?.emoji ?? "🛒")
                    .font(.title3)
                    .frame(width: 32)
            }

            // Content
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.unwrappedName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if !item.unwrappedQuantity.isEmpty {
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(item.unwrappedQuantity)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !item.unwrappedStore.isEmpty {
                        Label(item.unwrappedStore, systemImage: "building.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if !shoppingMode {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    List {
        ShoppingItemRow(
            item: {
                let item = FoodItem(context: PersistenceController.preview.viewContext)
                item.name = "Milk"; item.quantity = "1L"; item.store = "REWE"; item.isInStock = false
                return item
            }(), onTap: {}
        )
        ShoppingItemRow(
            item: {
                let item = FoodItem(context: PersistenceController.preview.viewContext)
                item.name = "Bread"; item.quantity = "1 loaf"; item.isInStock = false
                return item
            }(), shoppingMode: true, onTap: {}, onCheck: {}
        )
    }
}
