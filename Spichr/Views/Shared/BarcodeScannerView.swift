//
//  BarcodeScannerView.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    
    @StateObject private var barcodeService = BarcodeService()
    @Environment(\.dismiss) private var dismiss
    
    // Extended closure: (code, productInfo, scannedDate)
    let onScan: (String, ProductInfo?, Date?) -> Void
    
    @State private var showError: Bool = false
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreview(barcodeService: barcodeService)
                .ignoresSafeArea()
            
            // Scanning Overlay
            VStack {
                Spacer()
                
                // Scanning Frame
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 300, height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(.white)
                            
                            Text("align_barcode")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.top, 8)
                        }
                    )
                
                Spacer()
                
                // Instructions
                VStack(spacing: 8) {
                    if let code = barcodeService.scannedCode {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(String(format: NSLocalizedString("scanned_code", comment: ""), code))
                                .font(.headline)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    } else {
                        Text("position_barcode")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 40)
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .padding()
                }
                
                Spacer()
            }
        }
        .task {
            do {
                try await barcodeService.startScanning { code in
                    let scannedDate = Date()
                    
                    // Try to fetch product info (optional)
                    Task {
                        var productInfo: ProductInfo? = nil
                        
                        do {
                            productInfo = try await barcodeService.lookupProduct(barcode: code)
                        } catch {
                            // Product lookup failed - continue with nil
                            print("⚠️ Product lookup failed: \(error)")
                        }
                        
                        // Call onScan with all 3 parameters
                        await MainActor.run {
                            onScan(code, productInfo, scannedDate)
                        }
                        
                        // Small delay to show scanned code before dismissing
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        await MainActor.run {
                            dismiss()
                        }
                    }
                }
            } catch {
                showError = true
            }
        }
        .onDisappear {
            barcodeService.stopScanning()
        }
        .alert("Scanner Error", isPresented: $showError) {
            Button(LocalizedStringKey("ok")) {
                dismiss()
            }
        } message: {
            if let error = barcodeService.error {
                Text(error.localizedDescription)
            } else {
                Text(LocalizedStringKey("error_unknown"))
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    
    let barcodeService: BarcodeService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        DispatchQueue.main.async {
            if let previewLayer = barcodeService.getPreviewLayer() {
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BarcodeScannerView { code, productInfo, scannedDate in
        print("Scanned: \(code)")
        if let info = productInfo {
            print("Product: \(info.name)")
        }
        if let date = scannedDate {
            print("Date: \(date)")
        }
    }
}
