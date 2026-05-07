//
//  SpichrWidget.swift
//  SpichrWidget
//

import WidgetKit
import SwiftUI

// MARK: - App Group Constants

private let appGroupID = "group.com.de.SkerskiDev.FoodGuard"

// MARK: - Timeline Entry

struct SpichrEntry: TimelineEntry {
    let date: Date
    let expiredCount: Int
    let criticalItems: [WidgetItem]
    let totalStock: Int
}

struct WidgetItem: Identifiable {
    let id: UUID
    let name: String
    let daysLeft: Int
    let emoji: String
}

// MARK: - Provider

struct SpichrProvider: TimelineProvider {

    func placeholder(in context: Context) -> SpichrEntry {
        SpichrEntry(date: Date(), expiredCount: 1, criticalItems: [
            WidgetItem(id: UUID(), name: "Milk", daysLeft: 1, emoji: "🥛"),
            WidgetItem(id: UUID(), name: "Yogurt", daysLeft: 2, emoji: "🥛"),
        ], totalStock: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpichrEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpichrEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> SpichrEntry {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return SpichrEntry(date: Date(), expiredCount: 0, criticalItems: [], totalStock: 0)
        }

        let expiringCount = defaults.integer(forKey: "widget_expiring_count")
        let totalStock = defaults.integer(forKey: "widget_total_stock")

        let rawItems = defaults.array(forKey: "widget_critical_items") as? [[String: Any]] ?? []
        let criticalItems: [WidgetItem] = rawItems.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let daysLeft = dict["daysLeft"] as? Int else { return nil }
            let emoji = dict["emoji"] as? String ?? "📦"
            return WidgetItem(id: UUID(), name: name, daysLeft: daysLeft, emoji: emoji)
        }

        return SpichrEntry(
            date: Date(),
            expiredCount: expiringCount,
            criticalItems: criticalItems,
            totalStock: totalStock
        )
    }
}

// MARK: - Widget Views

struct SpichrWidgetSmall: View {
    let entry: SpichrEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .foregroundStyle(.tint)
                Text("Spichr")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if entry.expiredCount > 0 {
                Label("\(entry.expiredCount) expiring", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            Spacer()

            if let first = entry.criticalItems.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(first.emoji + " " + first.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(first.daysLeft == 0 ? "Today!" : "in \(first.daysLeft)d")
                        .font(.caption)
                        .foregroundStyle(first.daysLeft <= 1 ? .red : .orange)
                }
            } else {
                Text("✅ All good!")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            Text("\(entry.totalStock) items")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct SpichrWidgetMedium: View {
    let entry: SpichrEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Spichr", systemImage: "archivebox.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.totalStock)")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                    Text("items in stock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if entry.expiredCount > 0 {
                    Label("\(entry.expiredCount) expiring soon", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Expiring soon")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                if entry.criticalItems.isEmpty {
                    Text("✅ Nothing critical")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.criticalItems.prefix(3)) { item in
                        HStack {
                            Text(item.emoji + " " + item.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(item.daysLeft == 0 ? "Today" : "\(item.daysLeft)d")
                                .font(.caption.bold())
                                .foregroundStyle(item.daysLeft <= 1 ? .red : .orange)
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

// MARK: - Widget Configurations

struct SpichrWidget: Widget {
    let kind = "SpichrWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpichrProvider()) { entry in
            SpichrWidgetSmall(entry: entry)
        }
        .configurationDisplayName("Spichr")
        .description("See expiring items at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SpichrWidgetMediumConfig: Widget {
    let kind = "SpichrWidgetMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpichrProvider()) { entry in
            SpichrWidgetMedium(entry: entry)
        }
        .configurationDisplayName("Spichr — Detail")
        .description("Expiring items and stock overview.")
        .supportedFamilies([.systemMedium])
    }
}
