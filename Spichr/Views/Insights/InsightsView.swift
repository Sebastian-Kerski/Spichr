//
//  InsightsView.swift
//  Spichr
//

import SwiftUI
import Charts

struct InsightsView: View {

    @State private var items: [FoodItem] = []
    private let repository = FoodItemRepository()

    // MARK: - Computed stats

    private var stockItems: [FoodItem] { items.filter { $0.isInStock } }

    private var statusData: [(label: String, count: Int, color: Color)] {
        let expiredCount = stockItems.filter { $0.expirationStatus == .expired }.count
        let criticalCount = stockItems.filter { $0.expirationStatus == .critical || $0.expirationStatus == .expiringToday }.count
        let warningCount = stockItems.filter { $0.expirationStatus == .warning }.count
        let okCount = stockItems.filter { $0.expirationStatus == .approaching || $0.expirationStatus == .fresh }.count
        let unknownCount = stockItems.filter { $0.expirationStatus == .unknown }.count

        let data: [(label: String, count: Int, color: Color)] = [
            (NSLocalizedString("group_expired", comment: ""), expiredCount, .red),
            (NSLocalizedString("group_critical", comment: ""), criticalCount, .orange),
            (NSLocalizedString("group_warning", comment: ""), warningCount, .yellow),
            (NSLocalizedString("group_ok", comment: ""), okCount, .green),
            (NSLocalizedString("group_no_date", comment: ""), unknownCount, .gray)
        ]

        return data.filter { $0.count > 0 }
    }

    private var locationData: [(location: String, count: Int)] {
        let grouped = Dictionary(grouping: stockItems) { (item: FoodItem) -> String in
            item.unwrappedLocation.isEmpty ? NSLocalizedString("no_location", comment: "") : item.unwrappedLocation
        }
        let mapped: [(location: String, count: Int)] = grouped.map { (location: $0.key, count: $0.value.count) }
        let sorted = mapped.sorted { (a: (location: String, count: Int), b: (location: String, count: Int)) -> Bool in
            a.count > b.count
        }
        return Array(sorted.prefix(6))
    }

    private var categoryData: [(category: ItemCategory, count: Int)] {
        let grouped = Dictionary(grouping: stockItems.compactMap { (item: FoodItem) -> ItemCategory? in item.itemCategory }) { (cat: ItemCategory) -> ItemCategory in cat }
        let mapped: [(category: ItemCategory, count: Int)] = grouped.map { (category: $0.key, count: $0.value.count) }
        return mapped.sorted { (a: (category: ItemCategory, count: Int), b: (category: ItemCategory, count: Int)) -> Bool in
            a.count > b.count
        }
    }

    private var upcomingItems: [FoodItem] {
        let filtered = stockItems.filter { (item: FoodItem) -> Bool in
            guard let days = item.daysUntilExpiration else { return false }
            return days >= 0 && days <= 14
        }
        return filtered.sorted { (a: FoodItem, b: FoodItem) -> Bool in
            (a.daysUntilExpiration ?? 0) < (b.daysUntilExpiration ?? 0)
        }
    }

    // MARK: - Body

    @State private var showRecipes = false

    var body: some View {
        NavigationStack {
            List {
                recipesBannerSection
                summarySection
                if !statusData.isEmpty { statusChartSection }
                if !upcomingItems.isEmpty { upcomingSection }
                if !locationData.isEmpty { locationChartSection }
                if !categoryData.isEmpty { categorySection }
            }
            .navigationTitle(LocalizedStringKey("insights_title"))
            .onAppear { items = repository.fetchAllItems() }
            .sheet(isPresented: $showRecipes) {
                RecipeSuggestionView()
            }
        }
    }

    // MARK: - Recipes Banner

    private var recipesBannerSection: some View {
        Section {
            Button {
                showRecipes = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("recipes_banner_title"))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(LocalizedStringKey("recipes_banner_subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SummaryCard(
                    value: stockItems.count,
                    label: LocalizedStringKey("total_items"),
                    icon: "archivebox.fill",
                    color: .blue
                )
                SummaryCard(
                    value: statusData.first(where: { $0.color == .red })?.count ?? 0,
                    label: LocalizedStringKey("group_expired"),
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
                SummaryCard(
                    value: upcomingItems.count,
                    label: LocalizedStringKey("expiring_soon"),
                    icon: "clock.fill",
                    color: .orange
                )
                SummaryCard(
                    value: items.filter { !$0.isInStock }.count,
                    label: LocalizedStringKey("shopping_items"),
                    icon: "cart.fill",
                    color: .green
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Status Donut Chart

    private var statusChartSection: some View {
        Section(LocalizedStringKey("insights_status_breakdown")) {
            Chart(statusData, id: \.label) { entry in
                SectorMark(
                    angle: .value("Count", entry.count),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .foregroundStyle(entry.color)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .padding(.vertical, 8)

            ForEach(statusData, id: \.label) { entry in
                HStack {
                    Circle().fill(entry.color).frame(width: 10, height: 10)
                    Text(entry.label).font(.caption)
                    Spacer()
                    Text("\(entry.count)").font(.caption.bold())
                }
            }
        }
    }

    // MARK: - Upcoming Expiry

    private var upcomingSection: some View {
        Section(LocalizedStringKey("insights_expiring_14_days")) {
            Chart(upcomingItems.prefix(10), id: \.objectID) { item in
                BarMark(
                    x: .value("Days", item.daysUntilExpiration ?? 0),
                    y: .value("Item", item.unwrappedName)
                )
                .foregroundStyle(barColor(for: item))
                .cornerRadius(4)
            }
            .chartXAxisLabel(LocalizedStringKey("insights_days_remaining"))
            .frame(height: CGFloat(min(upcomingItems.count, 10)) * 36 + 40)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Location Chart

    private var locationChartSection: some View {
        Section(LocalizedStringKey("insights_by_location")) {
            Chart(locationData, id: \.location) { entry in
                BarMark(
                    x: .value("Count", entry.count),
                    y: .value("Location", entry.location)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
            .frame(height: CGFloat(locationData.count) * 36 + 40)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        Section(LocalizedStringKey("insights_by_category")) {
            ForEach(categoryData, id: \.category) { entry in
                HStack {
                    Text(entry.category.emoji).font(.title3).frame(width: 30)
                    Text(entry.category.localizedName)
                    Spacer()
                    Text("\(entry.count)")
                        .font(.headline)
                        .foregroundStyle(entry.category.color)
                    ProgressView(value: Double(entry.count), total: Double(stockItems.count))
                        .frame(width: 60)
                        .tint(entry.category.color)
                }
            }
        }
    }

    private func barColor(for item: FoodItem) -> Color {
        switch item.expirationStatus {
        case .expired, .expiringToday: return .red
        case .critical: return .orange
        case .warning: return .yellow
        default: return .green
        }
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let value: Int
    let label: LocalizedStringKey
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    InsightsView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
