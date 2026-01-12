//
//  SettingsViewModel.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Foundation
import SwiftUI
import CloudKit

@Observable
final class SettingsViewModel {
    
    // MARK: - Notification Settings
    
    var notificationsEnabled: Bool {
        get { NotificationService.shared.isAuthorized }
        set { /* Handled via requestAuthorization */ }
    }
    
    var dailySummaryEnabled: Bool {
        get { NotificationService.shared.settings.dailySummaryEnabled }
        set {
            NotificationService.shared.settings.dailySummaryEnabled = newValue
            NotificationService.shared.rescheduleAllNotifications()
            saveSettings()
        }
    }
    
    var dailySummaryTime: Date {
        get {
            let components = NotificationService.shared.dailySummaryTime
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            NotificationService.shared.dailySummaryTime = components
            NotificationService.shared.scheduleDailySummary()
            saveSettings()
        }
    }
    
    var expiring30DaysEnabled: Bool {
        get { NotificationService.shared.settings.expiringIn30DaysEnabled }
        set {
            NotificationService.shared.settings.expiringIn30DaysEnabled = newValue
            NotificationService.shared.rescheduleAllNotifications()
            saveSettings()
        }
    }
    
    var expiring7DaysEnabled: Bool {
        get { NotificationService.shared.settings.expiringIn7DaysEnabled }
        set {
            NotificationService.shared.settings.expiringIn7DaysEnabled = newValue
            NotificationService.shared.rescheduleAllNotifications()
            saveSettings()
        }
    }
    
    var expiring1DayEnabled: Bool {
        get { NotificationService.shared.settings.expiringIn1DayEnabled }
        set {
            NotificationService.shared.settings.expiringIn1DayEnabled = newValue
            NotificationService.shared.rescheduleAllNotifications()
            saveSettings()
        }
    }
    
    var expiringTodayEnabled: Bool {
        get { NotificationService.shared.settings.expiringTodayEnabled }
        set {
            NotificationService.shared.settings.expiringTodayEnabled = newValue
            NotificationService.shared.rescheduleAllNotifications()
            saveSettings()
        }
    }
    
    var openedItemsEnabled: Bool {
        get { NotificationService.shared.settings.openedItemsEnabled }
        set {
            NotificationService.shared.settings.openedItemsEnabled = newValue
            NotificationService.shared.rescheduleAllNotifications()
            saveSettings()
        }
    }
    
    // MARK: - iCloud Settings
    
    var iCloudSyncEnabled: Bool = true // Always enabled with CloudKit
    var iCloudAccountStatus: String = "Checking..."
    
    // MARK: - App Info
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - Statistics
    
    var totalItems: Int = 0
    var stockItems: Int = 0
    var shoppingItems: Int = 0
    var expiringItemsCount: Int = 0
    
    // MARK: - Dependencies
    
    private let repository = FoodItemRepository()
    private let notificationService = NotificationService.shared
    
    // MARK: - Initialization
    
    init() {
        loadStatistics()
        checkiCloudStatus()
    }
    
    // MARK: - Actions
    
    func requestNotificationAuthorization() async {
        let granted = await notificationService.requestAuthorization()
        if granted {
            notificationService.registerNotificationCategories()
            notificationService.rescheduleAllNotifications()
        }
    }
    
    func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func loadStatistics() {
        totalItems = repository.fetchAllItems().count
        stockItems = repository.getStockCount()
        shoppingItems = repository.getShoppingListCount()
        expiringItemsCount = repository.getExpiringItemsCount(withinDays: 7)
    }
    
    func checkiCloudStatus() {
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.de.SkerskiDev.FoodGuard")
                let status = try await container.accountStatus()
                await MainActor.run {
                    iCloudAccountStatus = status == .available ? "Connected" : "Not Available"
                }
            } catch {
                await MainActor.run {
                    iCloudAccountStatus = "Error"
                }
            }
        }
    }
    
    func exportData() async throws -> URL {
        // Create CSV export of all items
        let items = repository.fetchAllItems()
        
        var csvString = "Name,Quantity,Location,Store,Expiration Date,In Stock\n"
        
        for item in items {
            let expirationString = item.expirationDate?.formatted(date: .numeric, time: .omitted) ?? ""
            csvString += "\"\(item.unwrappedName)\",\"\(item.unwrappedQuantity)\",\"\(item.unwrappedLocation)\",\"\(item.unwrappedStore)\",\"\(expirationString)\",\(item.isInStock)\n"
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("spichr_export.csv")
        try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return tempURL
    }
    
    func deleteAllData() async throws {
        try await PersistenceController.shared.deleteAllData()
        notificationService.cancelAllNotifications()
        loadStatistics()
    }
    
    private func saveSettings() {
        // Settings are automatically saved via NotificationService
        // Could add UserDefaults persistence here if needed
    }
}
