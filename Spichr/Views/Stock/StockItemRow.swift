//
//  StockItemRow.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import CoreData

struct StockItemRow: View {
    
    let item: FoodItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status Indicator
                ExpirationBadge(status: item.expirationStatus)
                
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
                    
                    // Location & Expiration Info
                    HStack(spacing: 8) {
                        if !item.unwrappedLocation.isEmpty {
                            Label(item.unwrappedLocation, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if item.effectiveExpirationDate != nil {
                            Label(item.expirationDisplayText, systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(item.expirationStatus.color)
                        }
                    }
                    
                    // Opened Date Info
                    if let openedDate = item.openedDate {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Opened \(openedDate.formatted(.relative(presentation: .named)))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expiration Badge

struct ExpirationBadge: View {
    let status: ExpirationStatus
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .strokeBorder(status.color.opacity(0.3), lineWidth: 3)
            )
    }
}

// MARK: - Status Color Extension

extension ExpirationStatus {
    var color: Color {
        switch self {
        case .expired:
            return .red
        case .expiringToday, .critical:
            return .orange
        case .warning:
            return .yellow
        case .approaching:
            return .blue
        case .fresh:
            return .green
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview("Fresh Item") {
    List {
        StockItemRow(
            item: {
                let item = FoodItem(context: PersistenceController.preview.viewContext)
                item.name = "Milk"
                item.quantity = "1L"
                item.location = "Kühlschrank"
                item.expirationDate = Calendar.current.date(byAdding: .day, value: 45, to: Date())
                return item
            }(),
            onTap: {}
        )
    }
}

#Preview("Critical Item") {
    List {
        StockItemRow(
            item: {
                let item = FoodItem(context: PersistenceController.preview.viewContext)
                item.name = "Yogurt"
                item.quantity = "500g"
                item.location = "Kühlschrank"
                item.expirationDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                return item
            }(),
            onTap: {}
        )
    }
}

#Preview("Expired Item") {
    List {
        StockItemRow(
            item: {
                let item = FoodItem(context: PersistenceController.preview.viewContext)
                item.name = "Old Cheese"
                item.quantity = "200g"
                item.location = "Kühlschrank"
                item.expirationDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
                return item
            }(),
            onTap: {}
        )
    }
}

#Preview("Opened Item") {
    List {
        StockItemRow(
            item: {
                let item = FoodItem(context: PersistenceController.preview.viewContext)
                item.name = "Cream"
                item.quantity = "250ml"
                item.location = "Kühlschrank"
                item.expirationDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())
                item.openedDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
                item.shelfLifeAfterOpeningDays = 3
                return item
            }(),
            onTap: {}
        )
    }
}
