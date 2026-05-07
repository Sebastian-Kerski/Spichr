//
//  ShoppingListView.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import CoreData
import Combine

struct ShoppingListView: View {
    
    @State private var viewModel = ShoppingListViewModel()
    @State private var showingAddItem = false
    @State private var itemToEdit: FoodItem?
    @State private var shoppingMode = false
    @State private var showingShareSheet = false
    @State private var shareText = ""
    
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
            .navigationTitle(LocalizedStringKey(shoppingMode ? "shopping_mode_active" : "shopping_list"))
            .searchable(
                text: $viewModel.searchQuery,
                prompt: Text("search_items")
            )
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $viewModel.showQuickAdd) {
                QuickAddSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAddItem) {
                AddEditItemView(mode: .add)
            }
            .sheet(item: $itemToEdit) { item in
                AddEditItemView(mode: .edit(item))
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(activityItems: [shareText])
            }
            .onAppear {
                viewModel.loadItems()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                .receive(on: DispatchQueue.main)) { _ in
                viewModel.loadItems()
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSPersistentCloudKitContainer.eventChangedNotification)
                .receive(on: DispatchQueue.main)) { notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event,
                      event.type == .import,
                      event.succeeded else { return }
                viewModel.loadItems()
            }
        }
    }

    // MARK: - Export

    private func exportShoppingList() {
        let title = NSLocalizedString("shopping_list_export_title", comment: "")
        var lines = [title, String(repeating: "-", count: title.count)]
        for item in viewModel.filteredItems {
            var line = "☐ \(item.unwrappedName)"
            if !item.unwrappedQuantity.isEmpty { line += " (\(item.unwrappedQuantity))" }
            if !item.unwrappedStore.isEmpty { line += " — \(item.unwrappedStore)" }
            lines.append(line)
        }
        shareText = lines.joined(separator: "\n")
        showingShareSheet = true
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.groupByStore {
            groupedView
        } else {
            listView
        }
    }
    
    // MARK: - Grouped View (by Store)
    
    private var groupedView: some View {
        List {
            ForEach(viewModel.sortedStoreGroups, id: \.key) { group in
                let store = group.key
                let items = group.value
                Section {
                    ForEach(items, id: \.objectID) { item in
                        ShoppingItemRow(item: item, shoppingMode: shoppingMode, onTap: {
                            if !shoppingMode { itemToEdit = item }
                        }, onCheck: {
                            withAnimation { viewModel.moveToStock(item) }
                        })
                        .shoppingSwipeActions(item: item, viewModel: viewModel, shoppingMode: shoppingMode)
                    }
                    .onDelete { offsets in
                        viewModel.deleteItems(at: offsets, from: items)
                    }
                } header: {
                    HStack {
                        Image(systemName: "building.2.fill")
                        Text(store)
                        Spacer()
                        Text("\(items.count)").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable { viewModel.loadItems() }
    }

    private var listView: some View {
        List {
            ForEach(viewModel.filteredItems, id: \.objectID) { item in
                ShoppingItemRow(item: item, shoppingMode: shoppingMode, onTap: {
                    if !shoppingMode { itemToEdit = item }
                }, onCheck: {
                    withAnimation { viewModel.moveToStock(item) }
                })
                .shoppingSwipeActions(item: item, viewModel: viewModel, shoppingMode: shoppingMode)
            }
            .onDelete { offsets in
                viewModel.deleteItems(at: offsets, from: viewModel.filteredItems)
            }
        }
        .refreshable { viewModel.loadItems() }
    }
    
    // MARK: - Empty States
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("empty_shopping_title"), systemImage: "cart")
        } description: {
            Text("empty_shopping_message")
        } actions: {
            Button(LocalizedStringKey("action_add_item")) {
                viewModel.presentQuickAdd()
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
            Button {
                withAnimation { shoppingMode.toggle() }
            } label: {
                Label(
                    LocalizedStringKey(shoppingMode ? "shopping_mode_exit" : "shopping_mode_start"),
                    systemImage: shoppingMode ? "cart.fill.badge.minus" : "cart.badge.plus"
                )
            }
            .tint(shoppingMode ? .orange : .accentColor)
        }

        ToolbarItem(placement: .secondaryAction) {
            Button {
                viewModel.presentQuickAdd()
            } label: {
                Label(LocalizedStringKey("action_quick_add"), systemImage: "plus.circle.fill")
            }
        }
        
        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Button {
                    viewModel.toggleGrouping()
                } label: {
                    Label {
                        Text(LocalizedStringKey(viewModel.groupByStore ? "show_as_list" : "group_by_store"))
                    } icon: {
                        Image(systemName: viewModel.groupByStore ? "list.bullet" : "building.2")
                    }
                }

                Divider()

                Button {
                    showingAddItem = true
                } label: {
                    Label(LocalizedStringKey("action_add_detailed_item"), systemImage: "plus.square")
                }

                if !viewModel.items.isEmpty {
                    Button {
                        exportShoppingList()
                    } label: {
                        Label(LocalizedStringKey("export_shopping_list"), systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button {
                        viewModel.moveAllToStock()
                    } label: {
                        Label(LocalizedStringKey("action_move_all_to_stock"), systemImage: "archivebox.fill")
                    }

                    Button(role: .destructive) {
                        viewModel.deleteAllItems()
                    } label: {
                        Label(LocalizedStringKey("action_clear_list"), systemImage: "trash")
                    }
                }
            } label: {
                Label(LocalizedStringKey("action_more"), systemImage: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Quick Add Sheet

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ShoppingListViewModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(LocalizedStringKey("field_item_name"), text: $viewModel.quickAddName)
                        .textInputAutocapitalization(.words)
                    
                    TextField(LocalizedStringKey("field_quantity_optional"), text: $viewModel.quickAddQuantity)
                    
                    TextField(LocalizedStringKey("field_store_optional"), text: $viewModel.quickAddStore)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle(LocalizedStringKey("action_quick_add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("action_cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("action_add")) {
                        viewModel.quickAddItem()
                        dismiss()
                    }
                    .disabled(viewModel.quickAddName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Swipe Action Helper

private extension View {
    func shoppingSwipeActions(item: FoodItem, viewModel: ShoppingListViewModel, shoppingMode: Bool) -> some View {
        self
            .swipeActions(edge: .trailing, allowsFullSwipe: !shoppingMode) {
                if !shoppingMode {
                    Button(role: .destructive) {
                        viewModel.deleteItem(item)
                    } label: {
                        Label(LocalizedStringKey("action_delete"), systemImage: "trash")
                    }
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if !shoppingMode {
                    Button {
                        viewModel.moveToStock(item)
                    } label: {
                        Label(LocalizedStringKey("action_add_to_stock"), systemImage: "archivebox.fill")
                    }
                    .tint(.green)
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ShoppingListView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

