//
//  FoodItemRepository.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Foundation
import CoreData
import Combine

/// Repository pattern for FoodItem CRUD operations
/// Provides clean separation between ViewModels and CoreData
final class FoodItemRepository {
    
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Fetch Operations
    
    /// Fetches all items (both in stock and shopping list)
    func fetchAllItems() -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)]
        
        do {
            return try persistenceController.viewContext.fetch(request)
        } catch {
            print("Error fetching all items: \(error)")
            return []
        }
    }
    
    /// Fetches items in stock
    func fetchStockItems() -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isInStock == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.expirationDate, ascending: true)
        ]
        
        do {
            return try persistenceController.viewContext.fetch(request)
        } catch {
            print("Error fetching stock items: \(error)")
            return []
        }
    }
    
    /// Fetches shopping list items
    func fetchShoppingListItems() -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isInStock == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)
        ]
        
        do {
            return try persistenceController.viewContext.fetch(request)
        } catch {
            print("Error fetching shopping list items: \(error)")
            return []
        }
    }
    
    /// Fetches items expiring within specified days
    func fetchExpiringItems(withinDays days: Int) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        
        request.predicate = NSPredicate(
            format: "isInStock == YES AND expirationDate != nil AND expirationDate <= %@",
            futureDate as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.expirationDate, ascending: true)
        ]
        
        do {
            return try persistenceController.viewContext.fetch(request)
        } catch {
            print("Error fetching expiring items: \(error)")
            return []
        }
    }
    
    /// Fetches items by location
    func fetchItems(byLocation location: String) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "location == %@ AND isInStock == YES", location)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.expirationDate, ascending: true)
        ]
        
        do {
            return try persistenceController.viewContext.fetch(request)
        } catch {
            print("Error fetching items by location: \(error)")
            return []
        }
    }
    
    /// Searches items by name
    func searchItems(query: String) -> [FoodItem] {
        guard !query.isEmpty else { return fetchAllItems() }
        
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)
        ]
        
        do {
            return try persistenceController.viewContext.fetch(request)
        } catch {
            print("Error searching items: \(error)")
            return []
        }
    }
    
    // MARK: - Create Operations
    
    /// Creates a new food item
    @discardableResult
    func createItem(
        name: String,
        quantity: String? = nil,
        location: String? = nil,
        store: String? = nil,
        expirationDate: Date? = nil,
        barcode: String? = nil,
        isInStock: Bool = false
    ) -> FoodItem {
        let item = FoodItem(context: persistenceController.viewContext)
        item.id = UUID()
        item.name = name
        item.quantity = quantity
        item.location = location
        item.store = store
        item.expirationDate = expirationDate
        item.barcode = barcode
        item.isInStock = isInStock
        item.lastModified = Date()
        
        persistenceController.save()
        
        // Schedule notifications if item is in stock
        if isInStock {
            NotificationService.shared.scheduleNotifications(for: item)
        }
        
        return item
    }
    
    // MARK: - Update Operations
    
    /// Updates an existing item
    func updateItem(
        _ item: FoodItem,
        name: String? = nil,
        quantity: String? = nil,
        location: String? = nil,
        store: String? = nil,
        expirationDate: Date? = nil,
        openedDate: Date? = nil,
        shelfLifeAfterOpeningDays: Int16? = nil,
        barcode: String? = nil,
        isInStock: Bool? = nil
    ) {
        if let name = name { item.name = name }
        if let quantity = quantity { item.quantity = quantity }
        if let location = location { item.location = location }
        if let store = store { item.store = store }
        if let expirationDate = expirationDate { item.expirationDate = expirationDate }
        if let openedDate = openedDate { item.openedDate = openedDate }
        if let shelfLife = shelfLifeAfterOpeningDays { item.shelfLifeAfterOpeningDays = shelfLife }
        if let barcode = barcode { item.barcode = barcode }
        if let isInStock = isInStock { item.isInStock = isInStock }
        
        item.lastModified = Date()
        persistenceController.save()
        
        // Reschedule notifications
        NotificationService.shared.cancelNotifications(for: item)
        if item.isInStock {
            NotificationService.shared.scheduleNotifications(for: item)
        }
    }
    
    /// Moves item between stock and shopping list
    func toggleStockStatus(_ item: FoodItem) {
        item.isInStock.toggle()
        item.lastModified = Date()
        persistenceController.save()
        
        // Update notifications based on new status
        if item.isInStock {
            NotificationService.shared.scheduleNotifications(for: item)
        } else {
            NotificationService.shared.cancelNotifications(for: item)
        }
    }
    
    /// Marks item as opened
    func markItemAsOpened(_ item: FoodItem, shelfLifeDays: Int16 = 0) {
        item.openedDate = Date()
        if shelfLifeDays > 0 {
            item.shelfLifeAfterOpeningDays = shelfLifeDays
        }
        item.lastModified = Date()
        persistenceController.save()
        
        // Reschedule with new expiration
        NotificationService.shared.cancelNotifications(for: item)
        NotificationService.shared.scheduleNotifications(for: item)
        if item.shelfLifeAfterOpeningDays > 0 {
            NotificationService.shared.scheduleOpenedItemNotification(for: item)
        }
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a single item
    func deleteItem(_ item: FoodItem) {
        NotificationService.shared.cancelNotifications(for: item)
        persistenceController.viewContext.delete(item)
        persistenceController.save()
    }
    
    /// Deletes multiple items
    func deleteItems(_ items: [FoodItem]) {
        items.forEach {
            NotificationService.shared.cancelNotifications(for: $0)
            persistenceController.viewContext.delete($0)
        }
        persistenceController.save()
    }
    
    /// Deletes all expired items
    func deleteExpiredItems() {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "expirationDate != nil AND expirationDate < %@",
            Date() as NSDate
        )
        
        do {
            let expiredItems = try persistenceController.viewContext.fetch(request)
            deleteItems(expiredItems)
        } catch {
            print("Error deleting expired items: \(error)")
        }
    }
    
    // MARK: - Statistics
    
    /// Returns count of items in stock
    func getStockCount() -> Int {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isInStock == YES")
        return (try? persistenceController.viewContext.count(for: request)) ?? 0
    }
    
    /// Returns count of shopping list items
    func getShoppingListCount() -> Int {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isInStock == NO")
        return (try? persistenceController.viewContext.count(for: request)) ?? 0
    }
    
    /// Returns count of expiring items (within days)
    func getExpiringItemsCount(withinDays days: Int) -> Int {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "isInStock == YES AND expirationDate != nil AND expirationDate <= %@",
            futureDate as NSDate
        )
        return (try? persistenceController.viewContext.count(for: request)) ?? 0
    }
    
    // MARK: - Household Filtering
    
    /// Fetches items for a specific household
    func fetchItems(forHousehold householdID: UUID) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "householdID == %@", householdID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)]
        
        do {
            return try persistenceController.viewContext.fetch(request)
        } catch {
            print("Error fetching items for household: \(error)")
            return []
        }
    }
    
    /// Fetches stock items for a specific household
    func fetchStockItems(forHousehold householdID: UUID) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "isInStock == YES AND householdID == %@",
            householdID as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.expirationDate, ascending: true)
        ]
        
        do {
            return try persistenceController.viewContext.fetch(request)
        } catch {
            print("Error fetching stock items for household: \(error)")
            return []
        }
    }
    
    /// Fetches shopping items for a specific household
    func fetchShoppingItems(forHousehold householdID: UUID) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "isInStock == NO AND householdID == %@",
            householdID as CVarArg
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)]
        
        do {
            return try persistenceController.viewContext.fetch(request)
        } catch {
            print("Error fetching shopping items for household: \(error)")
            return []
        }
    }
}
