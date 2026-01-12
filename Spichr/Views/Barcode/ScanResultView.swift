//
//  ScanResultView.swift
//  Spichr
//
//  Zeigt Scan-Ergebnis und ermöglicht Bestätigung/Ablehnung
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
                    
                    // Success Icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                        .padding(.top, 20)
                    
                    // Product Info Card
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Product Name
                        if let info = productInfo {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Produkt gefunden")
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
                            Text("Barcode")
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
                            Text("Gescannt am")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.blue)
                                Text(scannedDate, style: .date)
                                Text("um")
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
                                Text("Verfallsdatum hinzufügen")
                            }
                        }
                        .tint(.orange)
                        
                        if useExpirationDate {
                            DatePicker(
                                "Verfällt am",
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
                    
                    // Info Text
                    if productInfo == nil {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("Produktinformationen nicht verfügbar. Du kannst das Produkt trotzdem hinzufügen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Scan-Ergebnis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
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

#Preview("Mit ProductInfo") {
    ScanResultView(
        barcode: "4029764001807",
        productInfo: ProductInfo(
            name: "Vollmilch 3,5%",
            brand: "Landliebe",
            quantity: "1L",
            categories: "Milchprodukte",
            imageUrl: nil
        ),
        scannedDate: Date(),
        onConfirm: { code, info, date in
            print("Confirmed: \(code)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}

#Preview("Ohne ProductInfo") {
    ScanResultView(
        barcode: "1234567890123",
        productInfo: nil,
        scannedDate: Date(),
        onConfirm: { code, info, date in
            print("Confirmed: \(code)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
