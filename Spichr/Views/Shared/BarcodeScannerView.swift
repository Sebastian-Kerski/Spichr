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

    let onScan: (String, ProductInfo?, Date?) -> Void

    @State private var showError = false
    @State private var cameraWasDenied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera preview — updates when barcodeService.previewLayer is set
            CameraPreview(barcodeService: barcodeService)
                .ignoresSafeArea()

            scanOverlay
            closeButton
        }
        .task {
            do {
                try await barcodeService.startScanning { code in
                    Task {
                        var productInfo: ProductInfo?
                        do {
                            productInfo = try await barcodeService.lookupProduct(barcode: code)
                        } catch {
                            // Product lookup optional — continue with nil
                        }
                        await MainActor.run {
                            onScan(code, productInfo, Date())
                        }
                        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 s visual feedback
                        await MainActor.run { dismiss() }
                    }
                }
            } catch BarcodeError.cameraAccessDenied {
                cameraWasDenied = true
                showError = true
            } catch {
                await MainActor.run {
                    barcodeService.error = error as? BarcodeError
                    showError = true
                }
            }
        }
        .onDisappear {
            barcodeService.stopScanning()
        }
        .alert(LocalizedStringKey("error_scanner"), isPresented: $showError) {
            if cameraWasDenied {
                Button(LocalizedStringKey("open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    dismiss()
                }
            }
            Button(LocalizedStringKey("ok")) { dismiss() }
        } message: {
            if cameraWasDenied {
                Text(LocalizedStringKey("error_camera_denied"))
            } else if let err = barcodeService.error {
                Text(err.localizedDescription)
            } else {
                Text(LocalizedStringKey("error_unknown"))
            }
        }
    }

    // MARK: - Overlay

    private var scanOverlay: some View {
        VStack {
            Spacer()

            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 300, height: 200)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                        Text(LocalizedStringKey("align_barcode"))
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }

            Spacer()

            Group {
                if let code = barcodeService.scannedCode {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(String(format: NSLocalizedString("scanned_code", comment: ""), code))
                            .font(.headline)
                    }
                } else {
                    Text(LocalizedStringKey("position_barcode"))
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 40)
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .accessibilityLabel(LocalizedStringKey("action_close"))
                .padding()
            }
            Spacer()
        }
    }
}

// MARK: - Camera Preview

/// UIViewRepresentable wrapping a UIView subclass that positions the preview
/// layer correctly in layoutSubviews. Because `barcodeService.previewLayer`
/// is @Published, SwiftUI calls updateUIView whenever the layer becomes available,
/// which happens *after* startScanning() configures the AVCaptureSession.
struct CameraPreview: UIViewRepresentable {

    @ObservedObject var barcodeService: BarcodeService

    func makeUIView(context: Context) -> CameraPreviewView {
        CameraPreviewView()
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.setPreviewLayer(barcodeService.previewLayer)
    }
}

final class CameraPreviewView: UIView {

    private var currentPreviewLayer: AVCaptureVideoPreviewLayer?

    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer?) {
        if currentPreviewLayer === layer { return }
        currentPreviewLayer?.removeFromSuperlayer()
        currentPreviewLayer = layer
        if let layer {
            layer.frame = bounds
            self.layer.insertSublayer(layer, at: 0)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        currentPreviewLayer?.frame = bounds
    }
}

// MARK: - Preview

#Preview {
    BarcodeScannerView { _, _, _ in }
}
