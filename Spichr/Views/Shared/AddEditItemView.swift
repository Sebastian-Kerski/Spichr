//
//  AddEditItemView.swift
//  Spichr
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
                basicInfoSection
                categorySection
                locationSection
                datesSection
                advancedSection

                if viewModel.showValidationErrors && !viewModel.validationErrors.isEmpty {
                    validationErrorsSection
                }
            }
            .navigationTitle(viewModel.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $viewModel.showBarcodeScanner) {
                BarcodeScannerView { code, _, _ in
                    viewModel.handleScannedBarcode(code)
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

            Toggle(LocalizedStringKey("in_stock_toggle"), isOn: $viewModel.isInStock)
        } header: {
            Text(LocalizedStringKey("basic_information"))
        } footer: {
            Text(LocalizedStringKey("in_stock_toggle_hint"))
        }
    }

    private var categorySection: some View {
        Section(LocalizedStringKey("category")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "None" chip
                    Button {
                        viewModel.category = nil
                    } label: {
                        Text(LocalizedStringKey("category_none"))
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.category == nil ? Color.accentColor : Color.gray.opacity(0.15))
                            .foregroundStyle(viewModel.category == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }

                    ForEach(ItemCategory.allCases) { cat in
                        Button {
                            viewModel.category = cat
                        } label: {
                            HStack(spacing: 4) {
                                Text(cat.emoji)
                                Text(cat.localizedName)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.category == cat ? cat.color : Color.gray.opacity(0.15))
                            .foregroundStyle(viewModel.category == cat ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var locationSection: some View {
        Section(LocalizedStringKey("location_and_store")) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(LocalizedStringKey("field_location"), text: $viewModel.location)
                    .textInputAutocapitalization(.words)

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

            TextField(LocalizedStringKey("field_store_optional"), text: $viewModel.store)
                .textInputAutocapitalization(.words)
        }
    }

    private var datesSection: some View {
        Section {
            Toggle(LocalizedStringKey("has_expiration_date"), isOn: $viewModel.hasExpirationDate)

            if viewModel.hasExpirationDate {
                DatePicker(
                    LocalizedStringKey("expires_label"),
                    selection: $viewModel.expirationDate,
                    displayedComponents: .date
                )
            }

            if viewModel.isInStock {
                Toggle(LocalizedStringKey("already_opened"), isOn: $viewModel.hasOpenedDate)

                if viewModel.hasOpenedDate {
                    DatePicker(
                        LocalizedStringKey("scanned_on"),
                        selection: Binding(
                            get: { viewModel.openedDate ?? Date() },
                            set: { viewModel.openedDate = $0 }
                        ),
                        displayedComponents: .date
                    )

                    HStack {
                        Text(LocalizedStringKey("shelf_life_after_opening"))
                        Spacer()
                        TextField(LocalizedStringKey("field_days"), text: $viewModel.shelfLifeAfterOpeningDays)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
        } header: {
            Text(LocalizedStringKey("dates"))
        } footer: {
            if viewModel.hasOpenedDate {
                Text(LocalizedStringKey("expiration_calculation_hint"))
            }
        }
    }

    private var advancedSection: some View {
        Section(LocalizedStringKey("advanced_section")) {
            HStack {
                Text(LocalizedStringKey("field_barcode"))
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
    item.location = "Refrigerator"
    item.expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    item.isInStock = true
    return AddEditItemView(mode: .edit(item))
}
