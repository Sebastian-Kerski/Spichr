//
//  StockListView.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import CoreData

struct StockListView: View {
    
    @State private var viewModel = StockListViewModel()
    @State private var showingAddItem = false
    @State private var showingBarcodeScanner = false
    @State private var showingScanResult = false
    @State private var showingFilterSheet = false
    @State private var showingAddOptions = false
    @State private var itemToEdit: FoodItem?
    @State private var itemToShare: FoodItem?
    
    // Scan Result Data
    @State private var scannedBarcode: String = ""
    @State private var scannedProductInfo: ProductInfo?
    @State private var scannedDate: Date = Date()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else if viewModel.filteredItems.isEmpty {
                    searchEmptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("view_stock")
            .searchable(
                text: $viewModel.searchQuery,
                prompt: Text("search_items")
            )
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddItem) {
                AddEditItemView(mode: .add)
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView { code, productInfo, date in
                    // Speichere Scan-Daten
                    scannedBarcode = code
                    scannedProductInfo = productInfo
                    scannedDate = date ?? Date()
                    
                    // Zeige ScanResultView zur Bestätigung
                    showingScanResult = true
                }
            }
            .sheet(isPresented: $showingScanResult) {
                ScanResultView(
                    barcode: scannedBarcode,
                    productInfo: scannedProductInfo,
                    scannedDate: scannedDate,
                    onConfirm: { code, info, expirationDate in
                        // Erst JETZT speichern nach Bestätigung
                        Task {
                            await viewModel.confirmScannedProduct(
                                barcode: code,
                                productInfo: info,
                                expirationDate: expirationDate
                            )
                        }
                    },
                    onCancel: {
                        // User hat abgebrochen - nichts tun
                        print("❌ Scan cancelled by user")
                    }
                )
            }
            .sheet(item: $itemToEdit) { item in
                AddEditItemView(mode: .edit(item))
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadItems()
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Statistics Header
                if viewModel.statistics.hasIssues {
                    statisticsHeader
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                
                // Grouped Items
                ForEach(viewModel.sortedGroups, id: \.key) { group in
                    Section {
                        ForEach(group.value, id: \.objectID) { item in
                            StockItemRow(item: item) {
                                itemToEdit = item
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteItem(item)
                                } label: {
                                    Label(LocalizedStringKey("action_delete"), systemImage: "trash")
                                }
                                
                                Button {
                                    viewModel.moveToShoppingList(item)
                                } label: {
                                    Label(LocalizedStringKey("action_to_shopping"), systemImage: "cart.badge.plus")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading) {
                                if item.openedDate == nil {
                                    Button {
                                        viewModel.markAsOpened(item, shelfLifeDays: 0)
                                    } label: {
                                        Label(LocalizedStringKey("action_mark_opened"), systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                    } header: {
                        GroupHeader(group: group.key, count: group.value.count)
                    }
                }
            }
        }
        .refreshable {
            // Reload items - CoreData syncs automatically!
            viewModel.loadItems()
        }
    }
    
    // MARK: - Statistics Header
    
    private var statisticsHeader: some View {
        VStack(spacing: 8) {
            if viewModel.statistics.expiredCount > 0 {
                StatisticsBadge(
                    count: viewModel.statistics.expiredCount,
                    title: "status_expired",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
            
            if viewModel.statistics.criticalCount > 0 {
                StatisticsBadge(
                    count: viewModel.statistics.criticalCount,
                    title: "status_critical_1_2_days",
                    icon: "exclamationmark.circle.fill",
                    color: .orange
                )
            }
            
            if viewModel.statistics.warningCount > 0 {
                StatisticsBadge(
                    count: viewModel.statistics.warningCount,
                    title: "status_warning_3_7_days",
                    icon: "clock.fill",
                    color: .yellow
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty States
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("empty_stock_title"), systemImage: "archivebox")
        } description: {
            Text(LocalizedStringKey("empty_stock_message"))
        } actions: {
            Button(LocalizedStringKey("action_add_item")) {
                showingAddItem = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var searchEmptyStateView: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("no_results"), systemImage: "magnifyingglass")
        } description: {
            Text(LocalizedStringKey("try_different_search"))
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingBarcodeScanner = true
                } label: {
                    Label("scan_barcode", systemImage: "barcode.viewfinder")
                }
                
                Button {
                    showingAddItem = true
                } label: {
                    Label("add_manually", systemImage: "pencil")
                }
            } label: {
                Label("add_item", systemImage: "plus")
            } primaryAction: {
                // Primary action: Show barcode scanner first
                showingBarcodeScanner = true
            }
        }
        
        ToolbarItem(placement: .secondaryAction) {
            Menu {
                // Sort options
                Picker(LocalizedStringKey("action_sort_by"), selection: $viewModel.selectedSortOption) {
                    ForEach(StockListViewModel.SortOption.allCases) { option in
                        Label {
                            Text(option.localizedName)
                        } icon: {
                            Image(systemName: option.icon)
                        }
                        .tag(option)
                    }
                }
                
                Divider()
                
                // Filter
                Button {
                    showingFilterSheet = true
                } label: {
                    Label(LocalizedStringKey("action_filter"), systemImage: "line.3.horizontal.decrease.circle")
                }
                
                // Show/Hide expired
                Toggle(isOn: $viewModel.showExpiredItems) {
                    Label(LocalizedStringKey("action_show_expired"), systemImage: "eye")
                }
                
                Divider()
                
                // Bulk actions
                if viewModel.statistics.expiredCount > 0 {
                    Button(role: .destructive) {
                        viewModel.deleteExpiredItems()
                    } label: {
                        Label(LocalizedStringKey("action_delete_expired_items"), systemImage: "trash")
                    }
                }
            } label: {
                Label(LocalizedStringKey("action_more"), systemImage: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Group Header

struct GroupHeader: View {
    let group: StockListViewModel.ExpirationStatusGroup
    let count: Int
    
    var body: some View {
        HStack {
            Label {
                Text(group.title)
            } icon: {
                Image(systemName: group.icon)
            }
                .font(.headline)
                .foregroundStyle(group.color)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

// MARK: - Statistics Badge

struct StatisticsBadge: View {
    let count: Int
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(color)
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: StockListViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    Button {
                        viewModel.selectLocation(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Text("all_locations")
                            Spacer()
                            if viewModel.selectedLocation == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    ForEach(viewModel.availableLocations, id: \.self) { location in
                        Button {
                            viewModel.selectLocation(location)
                            dismiss()
                        } label: {
                            HStack {
                                Text(location)
                                Spacer()
                                if viewModel.selectedLocation == location {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("action_done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StockListView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
