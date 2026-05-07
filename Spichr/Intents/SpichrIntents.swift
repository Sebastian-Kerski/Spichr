//
//  SpichrIntents.swift
//  Spichr
//

import AppIntents
import CoreData

// MARK: - What Expires Soon

struct ExpiringItemsIntent: AppIntent {
    static let title: LocalizedStringResource = "What expires soon in Spichr?"
    static let description = IntentDescription("Returns expiring items within the next 3 days.")
    static let openAppWhenRun = false

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let repo = FoodItemRepository()
        let items = repo.fetchExpiringItems(withinDays: 3).prefix(3)

        let dialog: String
        if items.isEmpty {
            dialog = NSLocalizedString("siri_nothing_expiring", comment: "")
        } else {
            let list = items.map { item -> String in
                let days = item.daysUntilExpiration ?? 0
                if days == 0 {
                    return "\(item.unwrappedName) — today"
                } else if days == 1 {
                    return "\(item.unwrappedName) — tomorrow"
                } else {
                    return "\(item.unwrappedName) — in \(days) days"
                }
            }.joined(separator: "; ")
            dialog = String(format: NSLocalizedString("siri_expiring_list", comment: ""), list)
        }

        return .result(value: dialog, dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Show Shopping List

struct OpenShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "Show my Spichr shopping list"
    static let description = IntentDescription("Opens the shopping list in Spichr.")
    static let openAppWhenRun = true

    func perform() async throws -> some OpensIntent {
        return .result()
    }
}

// MARK: - Add Item

struct AddItemToSpichrIntent: AppIntent {
    static let title: LocalizedStringResource = "Add item to Spichr"
    static let description = IntentDescription("Opens Spichr ready to add a new item.")
    static let openAppWhenRun = true

    @Parameter(title: "Item name")
    var itemName: String?

    func perform() async throws -> some OpensIntent {
        // Store pending item name for ContentView to pick up
        if let name = itemName, !name.isEmpty {
            UserDefaults.standard.set(name, forKey: "siri_pending_item_name")
        }
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct SpichrAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        let shortcuts: [AppShortcut] = [
            AppShortcut(
                intent: ExpiringItemsIntent(),
                phrases: [
                    AppShortcutPhrase("What expires soon in \\(.applicationName)?"),
                    AppShortcutPhrase("Check expiring items in \\(.applicationName)"),
                    AppShortcutPhrase("What's about to expire in \\(.applicationName)?")
                ],
                shortTitle: "Check Expiring Items",
                systemImageName: "exclamationmark.triangle"
            ),
            AppShortcut(
                intent: OpenShoppingListIntent(),
                phrases: [
                    AppShortcutPhrase("Show my \\(.applicationName) shopping list"),
                    AppShortcutPhrase("Open shopping list in \\(.applicationName)")
                ],
                shortTitle: "Shopping List",
                systemImageName: "cart.fill"
            ),
            AppShortcut(
                intent: AddItemToSpichrIntent(),
                phrases: [
                    AppShortcutPhrase("Add item to \\(.applicationName)"),
                    AppShortcutPhrase("Add to \\(.applicationName)")
                ],
                shortTitle: "Add Item",
                systemImageName: "plus.circle.fill"
            )
        ]
        return shortcuts
    }
}

