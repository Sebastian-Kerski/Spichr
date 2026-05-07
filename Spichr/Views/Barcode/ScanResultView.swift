//
//  ScanResultView.swift
//  Spichr
//

import SwiftUI

struct ScanResultView: View {

    @Environment(\.dismiss) private var dismiss

    let barcode: String
    let productInfo: ProductInfo?
    let scannedDate: Date

    let onConfirm: (String, ProductInfo?, Date?) -> Void
    let onCancel: () -> Void

    @State private var useExpirationDate = false
    @State private var expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                        .padding(.top, 20)

                    // Product Info Card
                    VStack(alignment: .leading, spacing: 16) {

                        if let info = productInfo {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStringKey("product_found"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(info.name)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                if let brand = info.brand {
                                    HStack {
                                        Image(systemName: "building.2")
                                            .foregroundStyle(.secondary)
                                        Text(brand)
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                }

                                if let quantity = info.quantity {
                                    HStack {
                                        Image(systemName: "cube.box")
                                            .foregroundStyle(.secondary)
                                        Text(quantity)
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                }
                            }

                            Divider()
                        }

                        // Barcode
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("field_barcode"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Image(systemName: "barcode")
                                    .foregroundStyle(.blue)
                                Text(barcode)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                            }
                        }

                        Divider()

                        // Scan Date
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("scanned_on"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.blue)
                                Text(scannedDate, style: .date)
                                Text(LocalizedStringKey("at_time"))
                                    .foregroundStyle(.secondary)
                                Text(scannedDate, style: .time)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal)

                    // Expiration Date Section
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $useExpirationDate) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(.orange)
                                Text(LocalizedStringKey("add_expiration_date"))
                            }
                        }
                        .tint(.orange)

                        if useExpirationDate {
                            DatePicker(
                                LocalizedStringKey("expires_label"),
                                selection: $expirationDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal)

                    if productInfo == nil {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text(LocalizedStringKey("product_info_unavailable"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .navigationTitle(LocalizedStringKey("scan_result_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("action_cancel")) {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("action_add")) {
                        let expiry = useExpirationDate ? expirationDate : nil
                        onConfirm(barcode, productInfo, expiry)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With ProductInfo") {
    ScanResultView(
        barcode: "4029764001807",
        productInfo: ProductInfo(
            name: "Whole Milk 3.5%",
            brand: "Landliebe",
            quantity: "1L",
            categories: "Dairy",
            imageUrl: nil
        ),
        scannedDate: Date(),
        onConfirm: { _, _, _ in },
        onCancel: {}
    )
}

#Preview("Without ProductInfo") {
    ScanResultView(
        barcode: "1234567890123",
        productInfo: nil,
        scannedDate: Date(),
        onConfirm: { _, _, _ in },
        onCancel: {}
    )
}
