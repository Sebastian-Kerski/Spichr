//
//  AddEditItemViewModel.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Foundation
import SwiftUI

@Observable
final class AddEditItemViewModel {
    
    // MARK: - Mode
    
    enum Mode {
        case add
        case edit(FoodItem)
        
        var title: String {
            switch self {
            case .add:
                return NSLocalizedString("add_item", comment: "Add Item")
            case .edit:
                return NSLocalizedString("edit_item", comment: "Edit Item")
            }
        }
        
        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }
    }
    
    // MARK: - Properties
    
    let mode: Mode
    
    var name: String = ""
    var quantity: String = ""
    var location: String = ""
    var store: String = ""
    var barcode: String = ""
    var category: ItemCategory? = nil
    var expirationDate: Date = Date().addingTimeInterval(7 * 24 * 60 * 60)
    var hasExpirationDate: Bool = true
    var isInStock: Bool = true
    
    // Advanced
    var openedDate: Date?
    var hasOpenedDate: Bool = false
    var shelfLifeAfterOpeningDays: String = ""
    
    // Validation
    var showValidationErrors: Bool = false
    
    // Barcode
    var showBarcodeScanner: Bool = false
    var isLoadingProductInfo: Bool = false
    var productImageURL: String? = nil
    var productLookupFailed: Bool = false
    
    // MARK: - Dependencies
    
    private let repository: FoodItemRepository
    private let barcodeService = BarcodeService()
    
    // MARK: - Computed Properties
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(NSLocalizedString("error_name_required", comment: "Name is required"))
        }
        
        if hasOpenedDate, let opened = openedDate, opened > Date() {
            errors.append(NSLocalizedString("error_opened_future", comment: "Opened date cannot be in the future"))
        }
        
        if let shelfLife = Int16(shelfLifeAfterOpeningDays), shelfLife < 0 {
            errors.append(NSLocalizedString("error_shelf_life_negative", comment: "Shelf life cannot be negative"))
        }
        
        return errors
    }
    
    var saveButtonTitle: String {
        switch mode {
        case .add:
            return NSLocalizedString("add", comment: "Add")
        case .edit:
            return NSLocalizedString("save", comment: "Save")
        }
    }
    
    // Predefined locations
    var predefinedLocations: [String] {
        [
            NSLocalizedString("location_fridge", comment: "Fridge"),
            NSLocalizedString("location_freezer", comment: "Freezer"),
            NSLocalizedString("location_pantry", comment: "Pantry"),
            NSLocalizedString("location_counter", comment: "Counter"),
            NSLocalizedString("location_basement", comment: "Basement"),
        ]
    }
    
    // MARK: - Initialization
    
    init(mode: Mode, repository: FoodItemRepository = FoodItemRepository()) {
        self.mode = mode
        self.repository = repository
        
        // Populate fields if editing
        if case .edit(let item) = mode {
            populateFromItem(item)
        }
    }
    
    private func populateFromItem(_ item: FoodItem) {
        name = item.unwrappedName
        quantity = item.unwrappedQuantity
        location = item.unwrappedLocation
        store = item.unwrappedStore
        barcode = item.barcode ?? ""
        
        if let expDate = item.expirationDate {
            expirationDate = expDate
            hasExpirationDate = true
        } else {
            hasExpirationDate = false
        }
        
        isInStock = item.isInStock
        category = item.itemCategory

        if let opened = item.openedDate {
            openedDate = opened
            hasOpenedDate = true
        }
        
        if item.shelfLifeAfterOpeningDays > 0 {
            shelfLifeAfterOpeningDays = String(item.shelfLifeAfterOpeningDays)
        }
    }
    
    // MARK: - Actions
    
    func save() -> Bool {
        guard isValid else {
            showValidationErrors = true
            return false
        }
        
        let shelfLife = Int16(shelfLifeAfterOpeningDays) ?? 0
        
        switch mode {
        case .add:
            let newItem = repository.createItem(
                name: name.trimmingCharacters(in: .whitespaces),
                quantity: quantity.isEmpty ? nil : quantity,
                location: location.isEmpty ? nil : location,
                store: store.isEmpty ? nil : store,
                expirationDate: hasExpirationDate ? expirationDate : nil,
                barcode: barcode.isEmpty ? nil : barcode,
                category: category?.rawValue,
                isInStock: isInStock,
                productImageURL: productImageURL
            )

            if hasOpenedDate, let opened = openedDate, shelfLife > 0 {
                repository.updateItem(
                    newItem,
                    openedDate: opened,
                    shelfLifeAfterOpeningDays: shelfLife
                )
            }
            
        case .edit(let item):
            repository.updateItem(
                item,
                name: name.trimmingCharacters(in: .whitespaces),
                quantity: quantity.isEmpty ? nil : quantity,
                location: location.isEmpty ? nil : location,
                store: store.isEmpty ? nil : store,
                expirationDate: hasExpirationDate ? expirationDate : nil,
                openedDate: hasOpenedDate ? openedDate : nil,
                shelfLifeAfterOpeningDays: shelfLife,
                barcode: barcode.isEmpty ? nil : barcode,
                category: category?.rawValue,
                isInStock: isInStock,
                productImageURL: productImageURL
            )
        }
        
        return true
    }
    
    func clearForm() {
        name = ""
        quantity = ""
        location = ""
        store = ""
        barcode = ""
        expirationDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
        hasExpirationDate = true
        isInStock = true
        openedDate = nil
        hasOpenedDate = false
        shelfLifeAfterOpeningDays = ""
        showValidationErrors = false
    }
    
    func toggleExpirationDate() {
        hasExpirationDate.toggle()
    }
    
    func toggleOpenedDate() {
        hasOpenedDate.toggle()
        if hasOpenedDate && openedDate == nil {
            openedDate = Date()
        }
    }
    
    func selectLocation(_ location: String) {
        self.location = location
    }
    
    func scanBarcode() {
        showBarcodeScanner = true
    }
    
    func handleScannedBarcode(_ code: String) {
        barcode = code
        lookupBarcode(code)
    }
    
    func lookupBarcode(_ code: String) {
        isLoadingProductInfo = true
        productLookupFailed = false

        Task {
            do {
                let info = try await barcodeService.lookupProduct(barcode: code)

                await MainActor.run {
                    if name.isEmpty { name = info.name }
                    if quantity.isEmpty, let q = info.quantity { quantity = q }
                    if category == nil, let cats = info.categories {
                        category = mapOpenFoodFactsCategory(cats)
                    }
                    productImageURL = info.imageUrl
                    isLoadingProductInfo = false
                }
            } catch BarcodeError.productNotFound {
                await MainActor.run {
                    isLoadingProductInfo = false
                    productLookupFailed = true
                }
            } catch {
                await MainActor.run {
                    isLoadingProductInfo = false
                }
            }
        }
    }

    private func mapOpenFoodFactsCategory(_ cats: String) -> ItemCategory? {
        let lower = cats.lowercased()
        if lower.contains("dairy") || lower.contains("milk") || lower.contains("cheese") || lower.contains("yogurt") { return .dairy }
        if lower.contains("meat") || lower.contains("poultry") || lower.contains("beef") || lower.contains("chicken") { return .meat }
        if lower.contains("vegetable") || lower.contains("veggie") { return .vegetables }
        if lower.contains("fruit") { return .fruits }
        if lower.contains("beverage") || lower.contains("drink") || lower.contains("juice") { return .beverages }
        if lower.contains("canned") || lower.contains("preserved") { return .canned }
        if lower.contains("egg") { return .eggs }
        if lower.contains("grain") || lower.contains("cereal") || lower.contains("pasta") || lower.contains("rice") { return .grains }
        if lower.contains("bread") || lower.contains("bakery") || lower.contains("baked") { return .bakery }
        if lower.contains("sweet") || lower.contains("candy") || lower.contains("chocolate") || lower.contains("snack") { return .sweets }
        if lower.contains("condiment") || lower.contains("sauce") || lower.contains("spice") { return .condiments }
        if lower.contains("frozen") || lower.contains("ice cream") { return .frozen }
        return nil
    }
}
