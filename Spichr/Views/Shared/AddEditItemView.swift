//
//  AddEditItemView.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import CoreData

struct AddEditItemView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddEditItemViewModel
    
    init(mode: AddEditItemViewModel.Mode) {
        _viewModel = State(initialValue: AddEditItemViewModel(mode: mode))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                basicInfoSection
                
                // Location & Store
                locationSection
                
                // Dates
                datesSection
                
                // Advanced
                advancedSection
                
                // Validation Errors
                if viewModel.showValidationErrors && !viewModel.validationErrors.isEmpty {
                    validationErrorsSection
                }
            }
            .navigationTitle(viewModel.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $viewModel.showBarcodeScanner) {
                BarcodeScannerView { code, productInfo, scannedDate in
                    viewModel.handleScannedBarcode(code)
                    // TODO: Verwende productInfo und scannedDate wenn benötigt
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var basicInfoSection: some View {
        Section {
            TextField(LocalizedStringKey("field_name"), text: $viewModel.name)
                .textInputAutocapitalization(.words)
            
            TextField(LocalizedStringKey("field_quantity_optional"), text: $viewModel.quantity)
            
            Toggle("In Stock", isOn: $viewModel.isInStock)
        } header: {
            Text("basic_information")
        } footer: {
            Text("in_stock_toggle_hint")
        }
    }
    
    private var locationSection: some View {
        Section("Location & Store") {
            // Location with Quick Select
            VStack(alignment: .leading, spacing: 8) {
                TextField("Location", text: $viewModel.location)
                    .textInputAutocapitalization(.words)
                
                // Quick Location Buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.predefinedLocations, id: \.self) { location in
                            Button {
                                viewModel.selectLocation(location)
                            } label: {
                                Text(location)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        viewModel.location == location ? Color.blue : Color.gray.opacity(0.2)
                                    )
                                    .foregroundStyle(
                                        viewModel.location == location ? .white : .primary
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            TextField("Store (optional)", text: $viewModel.store)
                .textInputAutocapitalization(.words)
        }
    }
    
    private var datesSection: some View {
        Section {
            // Expiration Date
            Toggle("Has Expiration Date", isOn: $viewModel.hasExpirationDate)
            
            if viewModel.hasExpirationDate {
                DatePicker(
                    "Expires",
                    selection: $viewModel.expirationDate,
                    displayedComponents: .date
                )
            }
            
            // Opened Date
            if viewModel.isInStock {
                Toggle("Already Opened", isOn: $viewModel.hasOpenedDate)
                
                if viewModel.hasOpenedDate {
                    DatePicker(
                        "Opened",
                        selection: Binding(
                            get: { viewModel.openedDate ?? Date() },
                            set: { viewModel.openedDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    HStack {
                        Text("shelf_life_after_opening")
                        Spacer()
                        TextField("Days", text: $viewModel.shelfLifeAfterOpeningDays)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
        } header: {
            Text("dates")
        } footer: {
            if viewModel.hasOpenedDate {
                Text("expiration_calculation_hint")
            }
        }
    }
    
    private var advancedSection: some View {
        Section("Advanced") {
            HStack {
                Text("barcode")
                Spacer()
                
                if viewModel.isLoadingProductInfo {
                    ProgressView()
                } else if viewModel.barcode.isEmpty {
                    Button(LocalizedStringKey("action_scan")) {
                        viewModel.scanBarcode()
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(viewModel.barcode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button(LocalizedStringKey("action_clear")) {
                            viewModel.barcode = ""
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    private var validationErrorsSection: some View {
        Section {
            ForEach(viewModel.validationErrors, id: \.self) { error in
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(LocalizedStringKey("action_cancel")) {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button(viewModel.saveButtonTitle) {
                if viewModel.save() {
                    dismiss()
                }
            }
            .disabled(!viewModel.isValid)
        }
    }
}

// MARK: - Preview

#Preview("Add Mode") {
    AddEditItemView(mode: .add)
}

#Preview("Edit Mode") {
    let item = FoodItem(context: PersistenceController.preview.viewContext)
    item.name = "Milk"
    item.quantity = "1L"
    item.location = "Kühlschrank"
    item.expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    item.isInStock = true
    
    return AddEditItemView(mode: .edit(item))
}
