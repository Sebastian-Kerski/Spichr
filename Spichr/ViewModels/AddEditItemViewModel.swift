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
    var expirationDate: Date = Date().addingTimeInterval(7 * 24 * 60 * 60) // Default: 7 days
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
            NSLocalizedString("location_fridge", comment: "Kühlschrank"),
            NSLocalizedString("location_freezer", comment: "Gefrierschrank"),
            NSLocalizedString("location_pantry", comment: "Vorratsschrank"),
            NSLocalizedString("location_counter", comment: "Arbeitsplatte"),
            NSLocalizedString("location_basement", comment: "Keller"),
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
            repository.createItem(
                name: name.trimmingCharacters(in: .whitespaces),
                quantity: quantity.isEmpty ? nil : quantity,
                location: location.isEmpty ? nil : location,
                store: store.isEmpty ? nil : store,
                expirationDate: hasExpirationDate ? expirationDate : nil,
                barcode: barcode.isEmpty ? nil : barcode,
                isInStock: isInStock
            )
            
            // If item was created with opened date, update it
            if hasOpenedDate, let opened = openedDate, shelfLife > 0 {
                // Fetch the just-created item and update it
                // This is a bit hacky - in production you'd want createItem to return the item
                let items = repository.fetchAllItems()
                if let newItem = items.first(where: { $0.name == name.trimmingCharacters(in: .whitespaces) }) {
                    repository.updateItem(
                        newItem,
                        openedDate: opened,
                        shelfLifeAfterOpeningDays: shelfLife
                    )
                }
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
                isInStock: isInStock
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
        
        Task {
            do {
                let productInfo = try await barcodeService.lookupProduct(barcode: code)
                
                await MainActor.run {
                    // Prefill form with product info
                    if name.isEmpty {
                        name = productInfo.name
                    }
                    if quantity.isEmpty, let productQuantity = productInfo.quantity {
                        quantity = productQuantity
                    }
                    
                    isLoadingProductInfo = false
                }
            } catch {
                await MainActor.run {
                    isLoadingProductInfo = false
                    // Silently fail - user can still manually enter data
                    print("Product lookup failed: \(error)")
                }
            }
        }
    }
}
