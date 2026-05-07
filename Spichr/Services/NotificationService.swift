//
//  NotificationService.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Foundation
import Combine
import UserNotifications
import os

/// Manages all notification scheduling and handling
final class NotificationService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NotificationService()
    
    // MARK: - Published Properties
    
    @Published var isAuthorized: Bool = false
    @Published var dailySummaryTime: DateComponents = {
        let h = UserDefaults.standard.integer(forKey: "notif_summary_hour")
        let m = UserDefaults.standard.integer(forKey: "notif_summary_minute")
        return DateComponents(hour: h == 0 ? 9 : h, minute: m)
    }() {
        didSet {
            UserDefaults.standard.set(dailySummaryTime.hour ?? 9, forKey: "notif_summary_hour")
            UserDefaults.standard.set(dailySummaryTime.minute ?? 0, forKey: "notif_summary_minute")
        }
    }
    
    // MARK: - Configuration

    struct NotificationSettings {
        var dailySummaryEnabled: Bool
        var expiringIn30DaysEnabled: Bool
        var expiringIn7DaysEnabled: Bool
        var expiringIn1DayEnabled: Bool
        var expiringTodayEnabled: Bool
        var openedItemsEnabled: Bool

        static func load() -> NotificationSettings {
            func boolOrTrue(_ key: String) -> Bool {
                UserDefaults.standard.object(forKey: key) as? Bool ?? true
            }
            return NotificationSettings(
                dailySummaryEnabled:     boolOrTrue("notif_daily_summary"),
                expiringIn30DaysEnabled: boolOrTrue("notif_30days"),
                expiringIn7DaysEnabled:  boolOrTrue("notif_7days"),
                expiringIn1DayEnabled:   boolOrTrue("notif_1day"),
                expiringTodayEnabled:    boolOrTrue("notif_today"),
                openedItemsEnabled:      boolOrTrue("notif_opened")
            )
        }

        func save() {
            let d = UserDefaults.standard
            d.set(dailySummaryEnabled,     forKey: "notif_daily_summary")
            d.set(expiringIn30DaysEnabled, forKey: "notif_30days")
            d.set(expiringIn7DaysEnabled,  forKey: "notif_7days")
            d.set(expiringIn1DayEnabled,   forKey: "notif_1day")
            d.set(expiringTodayEnabled,    forKey: "notif_today")
            d.set(openedItemsEnabled,      forKey: "notif_opened")
        }
    }

    var settings = NotificationSettings.load() {
        didSet { settings.save() }
    }
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.de.SkerskiDev.Spichr", category: "Notifications")
    private let center = UNUserNotificationCenter.current()
    private let repository: FoodItemRepository
    
    // MARK: - Initialization
    
    override init() {
        self.repository = FoodItemRepository()
        super.init()
        center.delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            self.logger.error("Error requesting notification authorization: \(error.localizedDescription)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Schedule Notifications
    
    /// Schedules all notifications for a food item
    func scheduleNotifications(for item: FoodItem) {
        guard isAuthorized else { return }
        
        // Cancel existing notifications for this item
        cancelNotifications(for: item)
        
        // Get effective expiration date
        guard let expirationDate = item.effectiveExpirationDate else { return }
        
        let now = Date()
        guard expirationDate > now else { return } // Don't schedule for expired items
        
        let calendar = Calendar.current
        
        // Schedule 30 days before
        if settings.expiringIn30DaysEnabled {
            if let date30 = calendar.date(byAdding: .day, value: -30, to: expirationDate), date30 > now {
                scheduleNotification(
                    for: item,
                    at: date30,
                    title: NSLocalizedString("notification_expiring_title", comment: "Item expiring soon"),
                    body: String(format: NSLocalizedString("notification_expiring_30_days", comment: "%@ expires in 30 days"), item.unwrappedName),
                    identifier: "\(item.id?.uuidString ?? "")-30days"
                )
            }
        }
        
        // Schedule 7 days before
        if settings.expiringIn7DaysEnabled {
            if let date7 = calendar.date(byAdding: .day, value: -7, to: expirationDate), date7 > now {
                scheduleNotification(
                    for: item,
                    at: date7,
                    title: NSLocalizedString("notification_expiring_title", comment: "Item expiring soon"),
                    body: String(format: NSLocalizedString("notification_expiring_7_days", comment: "%@ expires in 7 days"), item.unwrappedName),
                    identifier: "\(item.id?.uuidString ?? "")-7days"
                )
            }
        }
        
        // Schedule 1 day before
        if settings.expiringIn1DayEnabled {
            if let date1 = calendar.date(byAdding: .day, value: -1, to: expirationDate), date1 > now {
                scheduleNotification(
                    for: item,
                    at: date1,
                    title: NSLocalizedString("notification_expiring_title", comment: "Item expiring soon"),
                    body: String(format: NSLocalizedString("notification_expiring_tomorrow", comment: "%@ expires tomorrow!"), item.unwrappedName),
                    identifier: "\(item.id?.uuidString ?? "")-1day"
                )
            }
        }
        
        // Schedule on expiration day (9 AM)
        if settings.expiringTodayEnabled {
            guard let expirationDayMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: expirationDate) else { return }
            if expirationDayMorning > now {
                scheduleNotification(
                    for: item,
                    at: expirationDayMorning,
                    title: NSLocalizedString("notification_expiring_today_title", comment: "Item expires today!"),
                    body: String(format: NSLocalizedString("notification_expiring_today", comment: "%@ expires today"), item.unwrappedName),
                    identifier: "\(item.id?.uuidString ?? "")-today"
                )
            }
        }
    }
    
    private func scheduleNotification(
        for item: FoodItem,
        at date: Date,
        title: String,
        body: String,
        identifier: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "FOOD_ITEM_EXPIRING"
        content.userInfo = [
            "itemId": item.id?.uuidString ?? "",
            "itemName": item.unwrappedName
        ]
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                self.logger.error("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Daily Summary
    
    func scheduleDailySummary() {
        guard isAuthorized, settings.dailySummaryEnabled else { return }
        
        // Cancel existing daily summary
        center.removePendingNotificationRequests(withIdentifiers: ["daily-summary"])
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification_daily_summary_title", comment: "Your Inventory")
        content.sound = .default
        content.categoryIdentifier = "DAILY_SUMMARY"
        
        // Get expiring items count
        let expiringCount = repository.getExpiringItemsCount(withinDays: 7)
        
        if expiringCount > 0 {
            content.body = String(
                format: NSLocalizedString("notification_daily_summary_body", comment: "You have %d items expiring soon"),
                expiringCount
            )
        } else {
            content.body = NSLocalizedString("notification_daily_summary_all_good", comment: "All items are fresh!")
        }
        
        // Schedule for configured time
        let trigger = UNCalendarNotificationTrigger(dateMatching: dailySummaryTime, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-summary", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                self.logger.error("Error scheduling daily summary: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Opened Items
    
    func scheduleOpenedItemNotification(for item: FoodItem) {
        guard isAuthorized, settings.openedItemsEnabled else { return }
        guard let openedDate = item.openedDate, item.shelfLifeAfterOpeningDays > 0 else { return }
        
        let calendar = Calendar.current
        guard let expirationDate = calendar.date(byAdding: .day, value: Int(item.shelfLifeAfterOpeningDays), to: openedDate) else { return }
        
        // Schedule 1 day before opened item expires
        guard let notificationDate = calendar.date(byAdding: .day, value: -1, to: expirationDate) else { return }
        guard notificationDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification_opened_item_title", comment: "Opened item expiring")
        content.body = String(
            format: NSLocalizedString("notification_opened_item_body", comment: "%@ was opened and expires soon"),
            item.unwrappedName
        )
        content.sound = .default
        content.categoryIdentifier = "OPENED_ITEM"
        content.userInfo = ["itemId": item.id?.uuidString ?? ""]
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "\(item.id?.uuidString ?? "")-opened"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                self.logger.error("Error scheduling opened item notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Cancel Notifications
    
    func cancelNotifications(for item: FoodItem) {
        guard let itemId = item.id?.uuidString else { return }
        
        let identifiers = [
            "\(itemId)-30days",
            "\(itemId)-7days",
            "\(itemId)-1day",
            "\(itemId)-today",
            "\(itemId)-opened"
        ]
        
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Reschedule All
    
    func rescheduleAllNotifications() {
        // Cancel all existing
        cancelAllNotifications()
        
        // Reschedule for all items in stock
        let items = repository.fetchStockItems()
        for item in items {
            scheduleNotifications(for: item)
            if item.openedDate != nil {
                scheduleOpenedItemNotification(for: item)
            }
        }
        
        // Reschedule daily summary
        scheduleDailySummary()
    }
    
    // MARK: - Badge Count
    
    func updateBadgeCount() {
        let expiringCount = repository.getExpiringItemsCount(withinDays: 7)
        UNUserNotificationCenter.current().setBadgeCount(expiringCount)
    }
    
    // MARK: - Notification Categories
    
    func registerNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ITEM",
            title: NSLocalizedString("notification_action_view", comment: "View"),
            options: .foreground
        )
        
        let deleteAction = UNNotificationAction(
            identifier: "DELETE_ITEM",
            title: NSLocalizedString("notification_action_delete", comment: "Delete"),
            options: .destructive
        )
        
        let foodItemCategory = UNNotificationCategory(
            identifier: "FOOD_ITEM_EXPIRING",
            actions: [viewAction, deleteAction],
            intentIdentifiers: [],
            options: []
        )
        
        let dailySummaryCategory = UNNotificationCategory(
            identifier: "DAILY_SUMMARY",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        let openedItemCategory = UNNotificationCategory(
            identifier: "OPENED_ITEM",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([foodItemCategory, dailySummaryCategory, openedItemCategory])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_ITEM":
            handleViewItem(userInfo: userInfo)
            
        case "DELETE_ITEM":
            handleDeleteItem(userInfo: userInfo)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped notification (not action button)
            handleViewItem(userInfo: userInfo)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleViewItem(userInfo: [AnyHashable: Any]) {
        guard let itemIdString = userInfo["itemId"] as? String,
              let itemId = UUID(uuidString: itemIdString) else { return }
        
        // Post notification to open specific item
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenFoodItem"),
            object: nil,
            userInfo: ["itemId": itemId]
        )
    }
    
    private func handleDeleteItem(userInfo: [AnyHashable: Any]) {
        guard let itemIdString = userInfo["itemId"] as? String,
              let itemId = UUID(uuidString: itemIdString) else { return }
        
        // Find and delete item
        let items = repository.fetchAllItems()
        if let item = items.first(where: { $0.id == itemId }) {
            repository.deleteItem(item)
        }
    }
}

