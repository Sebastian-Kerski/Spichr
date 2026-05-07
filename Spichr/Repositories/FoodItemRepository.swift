//
//  FoodItemRepository.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Foundation
import CoreData
import WidgetKit

/// Repository pattern for FoodItem CRUD operations.
final class FoodItemRepository {

    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Fetch Operations
    // fetchBatchSize is intentionally omitted on all requests: batch-fault cursors
    // are unreliable with NSPersistentCloudKitContainer's two stores (private + shared)
    // and produce "asked N objects but received M" errors.

    func fetchAllItems() -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    func fetchStockItems() -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isInStock == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.expirationDate, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    func fetchShoppingListItems() -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isInStock == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    func fetchExpiringItems(withinDays days: Int) -> [FoodItem] {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date(timeIntervalSinceNow: Double(days) * 86400)
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "isInStock == YES AND expirationDate != nil AND expirationDate <= %@",
            futureDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.expirationDate, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    func fetchItems(byLocation location: String) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "location == %@ AND isInStock == YES", location)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.expirationDate, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    func fetchItems(byCategory category: String) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@ AND isInStock == YES", category)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.expirationDate, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    func searchItems(query: String) -> [FoodItem] {
        guard !query.isEmpty else { return fetchAllItems() }
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    // MARK: - Create Operations

    @discardableResult
    func createItem(
        name: String,
        quantity: String? = nil,
        location: String? = nil,
        store: String? = nil,
        expirationDate: Date? = nil,
        barcode: String? = nil,
        category: String? = nil,
        isInStock: Bool = false,
        productImageURL: String? = nil
    ) -> FoodItem {
        let item = FoodItem(context: persistenceController.viewContext)
        item.id = UUID()
        item.name = name
        item.quantity = quantity
        item.location = location
        item.store = store
        item.expirationDate = expirationDate
        item.barcode = barcode
        item.category = category
        item.isInStock = isInStock
        item.productImageURL = productImageURL
        item.lastModified = Date()

        persistenceController.save()

        if isInStock {
            NotificationService.shared.scheduleNotifications(for: item)
            SpotlightService.shared.indexItem(item)
        }

        refreshWidgetData()
        return item
    }

    // MARK: - Update Operations

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
        category: String? = nil,
        isInStock: Bool? = nil,
        productImageURL: String? = nil
    ) {
        if let name { item.name = name }
        if let quantity { item.quantity = quantity }
        if let location { item.location = location }
        if let store { item.store = store }
        if let expirationDate { item.expirationDate = expirationDate }
        if let openedDate { item.openedDate = openedDate }
        if let shelfLife = shelfLifeAfterOpeningDays { item.shelfLifeAfterOpeningDays = shelfLife }
        if let barcode { item.barcode = barcode }
        if let category { item.category = category }
        if let isInStock { item.isInStock = isInStock }
        if let productImageURL { item.productImageURL = productImageURL }

        item.lastModified = Date()
        persistenceController.save()

        NotificationService.shared.cancelNotifications(for: item)
        if item.isInStock {
            NotificationService.shared.scheduleNotifications(for: item)
            SpotlightService.shared.indexItem(item)
        } else {
            SpotlightService.shared.removeItem(objectID: item.objectID)
        }

        refreshWidgetData()
    }

    func markAsConsumed(_ item: FoodItem) {
        let objectID = item.objectID
        NotificationService.shared.cancelNotifications(for: item)
        SpotlightService.shared.removeItem(objectID: objectID)
        persistenceController.viewContext.delete(item)
        persistenceController.save()
        refreshWidgetData()
    }

    func toggleStockStatus(_ item: FoodItem) {
        item.isInStock.toggle()
        item.lastModified = Date()
        persistenceController.save()

        if item.isInStock {
            NotificationService.shared.scheduleNotifications(for: item)
        } else {
            NotificationService.shared.cancelNotifications(for: item)
        }

        refreshWidgetData()
    }

    func markItemAsOpened(_ item: FoodItem, shelfLifeDays: Int16 = 0) {
        item.openedDate = Date()
        if shelfLifeDays > 0 { item.shelfLifeAfterOpeningDays = shelfLifeDays }
        item.lastModified = Date()
        persistenceController.save()

        NotificationService.shared.cancelNotifications(for: item)
        NotificationService.shared.scheduleNotifications(for: item)
        if item.shelfLifeAfterOpeningDays > 0 {
            NotificationService.shared.scheduleOpenedItemNotification(for: item)
        }

        refreshWidgetData()
    }

    // MARK: - Delete Operations

    func deleteItem(_ item: FoodItem) {
        let objectID = item.objectID
        NotificationService.shared.cancelNotifications(for: item)
        SpotlightService.shared.removeItem(objectID: objectID)
        persistenceController.viewContext.delete(item)
        persistenceController.save()
        refreshWidgetData()
    }

    func deleteItems(_ items: [FoodItem]) {
        items.forEach {
            NotificationService.shared.cancelNotifications(for: $0)
            SpotlightService.shared.removeItem(objectID: $0.objectID)
            persistenceController.viewContext.delete($0)
        }
        persistenceController.save()
        refreshWidgetData()
    }

    func deleteExpiredItems() {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "expirationDate != nil AND expirationDate < %@",
            Date() as NSDate
        )
        if let expiredItems = try? persistenceController.viewContext.fetch(request) {
            deleteItems(expiredItems)
        }
    }

    // MARK: - Statistics

    func getStockCount() -> Int {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isInStock == YES")
        return (try? persistenceController.viewContext.count(for: request)) ?? 0
    }

    func getShoppingListCount() -> Int {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isInStock == NO")
        return (try? persistenceController.viewContext.count(for: request)) ?? 0
    }

    func getExpiringItemsCount(withinDays days: Int) -> Int {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date(timeIntervalSinceNow: Double(days) * 86400)
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "isInStock == YES AND expirationDate != nil AND expirationDate <= %@",
            futureDate as NSDate
        )
        return (try? persistenceController.viewContext.count(for: request)) ?? 0
    }

    // MARK: - Household Filtering

    func fetchItems(forHousehold householdID: UUID) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "householdID == %@", householdID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    func fetchStockItems(forHousehold householdID: UUID) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "isInStock == YES AND householdID == %@",
            householdID as CVarArg
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.expirationDate, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    func fetchShoppingItems(forHousehold householdID: UUID) -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "isInStock == NO AND householdID == %@",
            householdID as CVarArg
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)]
        return (try? persistenceController.viewContext.fetch(request)) ?? []
    }

    // MARK: - Widget Data Bridge

    /// Writes a lightweight summary to App Group UserDefaults so the WidgetKit
    /// extension can display up-to-date counts without needing CoreData access.
    private func refreshWidgetData() {
        let stockItems = fetchStockItems()
        let expiringCount = stockItems.filter {
            guard let d = $0.daysUntilExpiration else { return false }
            return d >= 0 && d <= 7
        }.count

        let critical = stockItems
            .filter {
                guard let d = $0.daysUntilExpiration else { return false }
                return d >= 0 && d <= 3
            }
            .prefix(5)
            .map { item -> [String: Any] in
                [
                    "name": item.unwrappedName,
                    "daysLeft": item.daysUntilExpiration ?? 0,
                    "emoji": item.itemCategory?.emoji ?? "📦"
                ]
            }

        if let defaults = UserDefaults(suiteName: "group.com.de.SkerskiDev.FoodGuard") {
            defaults.set(expiringCount, forKey: "widget_expiring_count")
            defaults.set(stockItems.count, forKey: "widget_total_stock")
            defaults.set(Array(critical), forKey: "widget_critical_items")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
