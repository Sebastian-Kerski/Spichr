//
//  BarcodeService.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Foundation
import Combine
import AVFoundation
import SwiftUI
import AudioToolbox

/// Service for barcode scanning and product lookup
final class BarcodeService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isScanning: Bool = false
    @Published var scannedCode: String?
    @Published var productInfo: ProductInfo?
    @Published var error: BarcodeError?
    
    // MARK: - Scanner
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var onCodeScanned: ((String) -> Void)?
    
    // MARK: - Authorization
    
    func checkCameraAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
            
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
            
        case .denied, .restricted:
            await MainActor.run {
                error = .cameraAccessDenied
            }
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Start/Stop Scanning
    
    func startScanning(completion: @escaping (String) -> Void) async throws {
        guard await checkCameraAuthorization() else {
            throw BarcodeError.cameraAccessDenied
        }
        
        onCodeScanned = completion
        
        let session = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            throw BarcodeError.noCameraAvailable
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            throw BarcodeError.inputError
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            throw BarcodeError.inputError
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .pdf417, .qr, .code128, .code39, .code93,
                .upce, .aztec, .interleaved2of5, .itf14, .dataMatrix
            ]
        } else {
            throw BarcodeError.outputError
        }
        
        captureSession = session
        
        await MainActor.run {
            isScanning = true
        }
        
        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer = nil
        
        Task { @MainActor in
            isScanning = false
            onCodeScanned = nil
        }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
        }
        
        return previewLayer
    }
    
    // MARK: - Product Lookup
    
    /// Looks up product information from OpenFoodFacts API
    func lookupProduct(barcode: String) async throws -> ProductInfo {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        
        guard let url = URL(string: urlString) else {
            throw BarcodeError.invalidBarcode
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BarcodeError.networkError
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let apiResponse = try decoder.decode(OpenFoodFactsResponse.self, from: data)
        
        guard apiResponse.status == 1,
              let product = apiResponse.product else {
            throw BarcodeError.productNotFound
        }
        
        let info = ProductInfo(
            name: product.productName ?? product.productNameEn ?? "Unknown Product",
            brand: product.brands,
            quantity: product.quantity,
            categories: product.categories,
            imageUrl: product.imageFrontUrl
        )
        
        await MainActor.run {
            self.productInfo = info
        }
        
        return info
    }
    
    // MARK: - Convenience
    
    func scanAndLookup() async throws -> ProductInfo {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    try await startScanning { [weak self] code in
                        self?.stopScanning()
                        
                        Task {
                            do {
                                let info = try await self?.lookupProduct(barcode: code)
                                if let info = info {
                                    continuation.resume(returning: info)
                                }
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeService: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        // Vibrate on successful scan
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        scannedCode = stringValue
        onCodeScanned?(stringValue)
    }
}

// MARK: - Supporting Types

struct ProductInfo {
    let name: String
    let brand: String?
    let quantity: String?
    let categories: String?
    let imageUrl: String?
}

enum BarcodeError: LocalizedError {
    case cameraAccessDenied
    case noCameraAvailable
    case inputError
    case outputError
    case invalidBarcode
    case networkError
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .cameraAccessDenied:
            return NSLocalizedString("error_camera_denied", comment: "Camera access denied")
        case .noCameraAvailable:
            return NSLocalizedString("error_no_camera", comment: "No camera available")
        case .inputError, .outputError:
            return NSLocalizedString("error_camera_setup", comment: "Camera setup failed")
        case .invalidBarcode:
            return NSLocalizedString("error_invalid_barcode", comment: "Invalid barcode")
        case .networkError:
            return NSLocalizedString("error_network", comment: "Network error")
        case .productNotFound:
            return NSLocalizedString("error_product_not_found", comment: "Product not found")
        }
    }
}

// MARK: - OpenFoodFacts API Models

struct OpenFoodFactsResponse: Codable {
    let status: Int
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Codable {
    let productName: String?
    let productNameEn: String?
    let brands: String?
    let quantity: String?
    let categories: String?
    let imageFrontUrl: String?
}
