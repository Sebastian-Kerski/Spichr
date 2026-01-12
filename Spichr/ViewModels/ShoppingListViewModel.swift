//
//  ShoppingListViewModel.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Foundation
import SwiftUI

@Observable
final class ShoppingListViewModel {
    
    // MARK: - Published Properties
    
    var items: [FoodItem] = []
    var searchQuery: String = ""
    var groupByStore: Bool = true
    var selectedStore: String?
    var isLoading: Bool = false
    
    // Quick Add
    var showQuickAdd: Bool = false
    var quickAddName: String = ""
    var quickAddQuantity: String = ""
    var quickAddStore: String = ""
    
    // MARK: - Dependencies
    
    private let repository: FoodItemRepository
    
    // MARK: - Computed Properties
    
    var filteredItems: [FoodItem] {
        var result = items
        
        // Filter by search query
        if !searchQuery.isEmpty {
            result = result.filter { item in
                item.unwrappedName.localizedCaseInsensitiveContains(searchQuery) ||
                item.unwrappedStore.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Filter by store
        if let store = selectedStore {
            result = result.filter { $0.store == store }
        }
        
        return result.sorted { $0.unwrappedName < $1.unwrappedName }
    }
    
    var groupedByStore: [String: [FoodItem]] {
        guard groupByStore else { return [:] }
        
        return Dictionary(grouping: filteredItems) { item in
            let store = item.unwrappedStore
            return store.isEmpty ? NSLocalizedString("no_store", comment: "No Store") : store
        }
    }
    
    var sortedStoreGroups: [(key: String, value: [FoodItem])] {
        groupedByStore.sorted { lhs, rhs in
            // "No Store" always last
            if lhs.key == NSLocalizedString("no_store", comment: "No Store") { return false }
            if rhs.key == NSLocalizedString("no_store", comment: "No Store") { return true }
            return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }
    }
    
    var availableStores: [String] {
        Array(Set(items.compactMap { item in
            let store = item.unwrappedStore
            return store.isEmpty ? nil : store
        })).sorted()
    }
    
    var statistics: Statistics {
        Statistics(
            totalItems: items.count,
            storeCount: availableStores.count
        )
    }
    
    // MARK: - Initialization
    
    init(repository: FoodItemRepository = FoodItemRepository()) {
        self.repository = repository
    }
    
    // MARK: - Actions
    
    func loadItems() {
        isLoading = true
        items = repository.fetchShoppingListItems()
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
    
    func moveToStock(_ item: FoodItem) {
        repository.toggleStockStatus(item)
        loadItems()
    }
    
    func moveAllToStock() {
        items.forEach { repository.toggleStockStatus($0) }
        loadItems()
    }
    
    func clearSearch() {
        searchQuery = ""
    }
    
    func selectStore(_ store: String?) {
        selectedStore = store
    }
    
    func toggleGrouping() {
        groupByStore.toggle()
    }
    
    // MARK: - Quick Add
    
    func presentQuickAdd() {
        quickAddName = ""
        quickAddQuantity = ""
        quickAddStore = ""
        showQuickAdd = true
    }
    
    func dismissQuickAdd() {
        showQuickAdd = false
    }
    
    func quickAddItem() {
        guard !quickAddName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        repository.createItem(
            name: quickAddName,
            quantity: quickAddQuantity.isEmpty ? nil : quickAddQuantity,
            store: quickAddStore.isEmpty ? nil : quickAddStore,
            isInStock: false
        )
        
        loadItems()
        dismissQuickAdd()
    }
    
    // MARK: - Bulk Actions
    
    func deleteAllItems() {
        repository.deleteItems(items)
        loadItems()
    }
    
    func clearCompletedItems() {
        // This would be items marked as "bought" - for now just clear all
        // In future, add a "completed" or "bought" property
        deleteAllItems()
    }
}

// MARK: - Supporting Types

extension ShoppingListViewModel {
    
    struct Statistics {
        let totalItems: Int
        let storeCount: Int
        
        var isEmpty: Bool {
            totalItems == 0
        }
    }
}
