//
//  StockListViewModel.swift
//  Spichr - REWRITTEN FOR CLEAN CONCURRENCY
//
//  Created by Sebastian Skerski
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class StockListViewModel {
    
    // MARK: - Published Properties
    
    var items: [FoodItem] = []
    var searchQuery: String = ""
    var selectedLocation: String?
    var selectedSortOption: SortOption = .expirationDate
    var showExpiredItems: Bool = true
    var isLoading: Bool = false
    
    // Barcode scanning
    var scannedProductInfo: ProductInfo?
    var showProductQuickAdd: Bool = false
    
    // MARK: - Dependencies
    
    private let repository: FoodItemRepository
    private let barcodeService = BarcodeService()
    
    // MARK: - Computed Properties
    
    var filteredItems: [FoodItem] {
        var result = items
        
        // Filter by search query
        if !searchQuery.isEmpty {
            result = result.filter { item in
                item.unwrappedName.localizedCaseInsensitiveContains(searchQuery) ||
                item.unwrappedLocation.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Filter by location
        if let location = selectedLocation {
            result = result.filter { $0.location == location }
        }
        
        // Filter expired items
        if !showExpiredItems {
            result = result.filter { item in
                if let days = item.daysUntilExpiration {
                    return days >= 0
                }
                return true
            }
        }
        
        return result
    }
    
    var groupedItems: [ExpirationStatusGroup: [FoodItem]] {
        Dictionary(grouping: filteredItems) { item in
            ExpirationStatusGroup(from: item.expirationStatus)
        }
    }
    
    var sortedGroups: [(key: ExpirationStatusGroup, value: [FoodItem])] {
        groupedItems.sorted { $0.key < $1.key }
            .map { (key: $0.key, value: sortItems($0.value)) }
    }
    
    var availableLocations: [String] {
        Array(Set(items.compactMap { $0.location })).sorted()
    }
    
    var statistics: Statistics {
        Statistics(
            totalItems: items.count,
            expiredCount: items.filter { $0.expirationStatus == .expired }.count,
            criticalCount: items.filter { $0.expirationStatus == .critical || $0.expirationStatus == .expiringToday }.count,
            warningCount: items.filter { $0.expirationStatus == .warning }.count
        )
    }
    
    // MARK: - Initialization
    
    nonisolated init(repository: FoodItemRepository) {
        self.repository = repository
    }
    
    convenience init() {
        self.init(repository: FoodItemRepository(persistenceController: PersistenceController.shared))
    }
    
    // MARK: - Actions
    
    func loadItems() {
        isLoading = true
        items = repository.fetchStockItems()
        isLoading = false
    }
    
    func deleteItem(_ item: FoodItem) {
        repository.deleteItem(item)
        loadItems()
    }
    
    func deleteItems(at offsets: IndexSet, from items: [FoodItem]) {
        let itemsToDelete = offsets.map { items[$0] }
        repository.deleteItems(itemsToDelete)
        loadItems()
    }
    
    func moveToShoppingList(_ item: FoodItem) {
        repository.toggleStockStatus(item)
        loadItems()
    }
    
    func markAsOpened(_ item: FoodItem, shelfLifeDays: Int16) {
        repository.markItemAsOpened(item, shelfLifeDays: shelfLifeDays)
        loadItems()
    }
    
    func deleteExpiredItems() {
        repository.deleteExpiredItems()
        loadItems()
    }
    
    func selectLocation(_ location: String?) {
        selectedLocation = location
    }
    
    // MARK: - Barcode Handling
    
    /// Bestätigt gescanntes Produkt und speichert es
    /// Wird aufgerufen NACH User-Bestätigung in ScanResultView
    func confirmScannedProduct(
        barcode: String,
        productInfo: ProductInfo?,
        expirationDate: Date?
    ) async {
        await MainActor.run {
            // Verwende ProductInfo falls verfügbar, sonst Fallback
            let name = productInfo?.name ?? "Produkt \(barcode)"
            let quantity = productInfo?.quantity ?? ""
            let store = productInfo?.brand
            
            // Standard Location oder aus Settings
            let defaultLocation = "Kühlschrank"
            
            // Verfallsdatum: User-Wahl oder Default (+7 Tage)
            let expiry = expirationDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())
            
            // Erstelle Item
            repository.createItem(
                name: name,
                quantity: quantity,
                location: defaultLocation,
                store: store,
                expirationDate: expiry,
                barcode: barcode,
                isInStock: true
            )
            
            print("✅ Product confirmed and saved: \(name)")
            
            // Reload items
            loadItems()
        }
    }
    
    // MARK: - Legacy Method (unused)
    
    /// DEPRECATED: Alte Methode die automatisch speichert
    /// Wird nicht mehr verwendet - siehe confirmScannedProduct
    @available(*, deprecated, message: "Use confirmScannedProduct instead")
    func handleScannedBarcode(_ code: String) async {
        do {
            // Lookup product
            let info = try await barcodeService.lookupProduct(barcode: code)
            scannedProductInfo = info
            showProductQuickAdd = true
            
            // Auto-create item with product info
            repository.createItem(
                name: info.name,
                quantity: info.quantity ?? "",
                location: "Kühlschrank", // Default
                store: info.brand,
                expirationDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                barcode: code,
                isInStock: true
            )
            
            // Reload items
            loadItems()
            
        } catch {
            print("❌ Product lookup failed: \(error)")
            // Fallback: Open manual entry with barcode pre-filled
        }
    }
    
    // MARK: - Sorting
    
    private func sortItems(_ items: [FoodItem]) -> [FoodItem] {
        items.sorted { lhs, rhs in
            switch selectedSortOption {
            case .expirationDate:
                let lhsDate = lhs.expirationDate ?? Date.distantFuture
                let rhsDate = rhs.expirationDate ?? Date.distantFuture
                return lhsDate < rhsDate
            case .name:
                return lhs.unwrappedName < rhs.unwrappedName
            case .location:
                return lhs.unwrappedLocation < rhs.unwrappedLocation
            case .dateAdded:
                return (lhs.lastModified ?? Date.distantPast) > (rhs.lastModified ?? Date.distantPast)
            }
        }
    }
    
    // MARK: - Supporting Types
    
    enum SortOption: String, CaseIterable, Identifiable {
        case expirationDate = "Expiration Date"
        case name = "Name"
        case location = "Location"
        case dateAdded = "Date Added"
        
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .expirationDate: return NSLocalizedString("sort_expiration", comment: "")
            case .name: return NSLocalizedString("sort_name", comment: "")
            case .location: return NSLocalizedString("sort_location", comment: "")
            case .dateAdded: return NSLocalizedString("sort_date_added", comment: "")
            }
        }
        
        var icon: String {
            switch self {
            case .expirationDate: return "calendar"
            case .name: return "textformat"
            case .location: return "location"
            case .dateAdded: return "clock"
            }
        }
    }
    
    enum ExpirationStatusGroup: Comparable {
        case expired
        case critical
        case warning
        case ok
        case noDate
        
        init(from status: ExpirationStatus) {
            switch status {
            case .expired: self = .expired
            case .expiringToday, .critical: self = .critical
            case .warning: self = .warning
            case .approaching, .fresh: self = .ok
            case .unknown: self = .noDate
            }
        }
        
        var title: String {
            switch self {
            case .expired: return NSLocalizedString("group_expired", comment: "")
            case .critical: return NSLocalizedString("group_critical", comment: "")
            case .warning: return NSLocalizedString("group_warning", comment: "")
            case .ok: return NSLocalizedString("group_ok", comment: "")
            case .noDate: return NSLocalizedString("group_no_date", comment: "")
            }
        }
        
        var icon: String {
            switch self {
            case .expired: return "exclamationmark.triangle.fill"
            case .critical: return "exclamationmark.circle.fill"
            case .warning: return "clock.fill"
            case .ok: return "checkmark.circle.fill"
            case .noDate: return "calendar.badge.exclamationmark"
            }
        }
        
        var color: Color {
            switch self {
            case .expired: return .red
            case .critical: return .orange
            case .warning: return .yellow
            case .ok: return .green
            case .noDate: return .gray
            }
        }
        
        static func < (lhs: ExpirationStatusGroup, rhs: ExpirationStatusGroup) -> Bool {
            let order: [ExpirationStatusGroup] = [.expired, .critical, .warning, .ok, .noDate]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    struct Statistics {
        let totalItems: Int
        let expiredCount: Int
        let criticalCount: Int
        let warningCount: Int
        
        var hasIssues: Bool {
            expiredCount > 0 || criticalCount > 0 || warningCount > 0
        }
    }
}
