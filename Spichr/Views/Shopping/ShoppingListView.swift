//
//  ShoppingListView.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import CoreData

struct ShoppingListView: View {
    
    @State private var viewModel = ShoppingListViewModel()
    @State private var showingAddItem = false
    @State private var itemToEdit: FoodItem?
    
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
            .navigationTitle(LocalizedStringKey("shopping_list"))
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
            .onAppear {
                viewModel.loadItems()
            }
        }
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
                        ShoppingItemRow(item: item) {
                            itemToEdit = item
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteItem(item)
                            } label: {
                                Label(LocalizedStringKey("action_delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                viewModel.moveToStock(item)
                            } label: {
                                Label(LocalizedStringKey("action_add_to_stock"), systemImage: "archivebox.fill")
                            }
                            .tint(.green)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.deleteItems(at: offsets, from: items)
                    }
                } header: {
                    HStack {
                        Image(systemName: "building.2.fill")
                        Text(LocalizedStringKey(store))
                        Spacer()
                        Text("\(items.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadItems()
        }
    }
    
    // MARK: - List View (flat)
    
    private var listView: some View {
        List {
            ForEach(viewModel.filteredItems, id: \.objectID) { item in
                ShoppingItemRow(item: item) {
                    itemToEdit = item
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.deleteItem(item)
                    } label: {
                        Label(LocalizedStringKey("action_delete"), systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        viewModel.moveToStock(item)
                    } label: {
                        Label(LocalizedStringKey("action_add_to_stock"), systemImage: "archivebox.fill")
                    }
                    .tint(.green)
                }
            }
            .onDelete { offsets in
                viewModel.deleteItems(at: offsets, from: viewModel.filteredItems)
            }
        }
        .refreshable {
            viewModel.loadItems()
        }
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
                        Text(viewModel.groupByStore ? "Show as List" : "Group by Store")
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
                
                Divider()
                
                if !viewModel.items.isEmpty {
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

// MARK: - Preview

#Preview {
    ShoppingListView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

