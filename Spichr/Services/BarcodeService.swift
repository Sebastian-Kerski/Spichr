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
import UIKit
import CoreData

/// Service for barcode scanning and product lookup.
/// Key design notes:
/// - `previewLayer` is @Published so CameraPreview.updateUIView is triggered once the session
///   is configured (fixes the makeUIView race condition).
/// - `hasScanned` debounces the metadata callback — the delegate can fire for the same code
///   multiple times per second; only the first hit is forwarded.
/// - `startScanning` re-registers a foreground observer so the session restarts after the app
///   returns from the background.
final class BarcodeService: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isScanning: Bool = false
    @Published var scannedCode: String?
    @Published var productInfo: ProductInfo?
    @Published var error: BarcodeError?
    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Private State

    private var captureSession: AVCaptureSession?
    private var onCodeScanned: ((String) -> Void)?
    private var hasScanned = false
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Authorization

    func checkCameraAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            await MainActor.run { error = .cameraAccessDenied }
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Start / Stop Scanning

    func startScanning(completion: @escaping (String) -> Void) async throws {
        guard await checkCameraAuthorization() else {
            throw BarcodeError.cameraAccessDenied
        }

        onCodeScanned = completion
        hasScanned = false

        let session = AVCaptureSession()
        session.beginConfiguration()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            throw BarcodeError.noCameraAvailable
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            throw BarcodeError.inputError
        }

        guard session.canAddInput(videoInput) else { throw BarcodeError.inputError }
        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { throw BarcodeError.outputError }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [
            .ean8, .ean13, .pdf417, .qr, .code128, .code39, .code93,
            .upce, .aztec, .interleaved2of5, .itf14, .dataMatrix
        ]

        session.commitConfiguration()
        captureSession = session

        // Create the preview layer now that the session is configured.
        // Publishing this triggers CameraPreview.updateUIView, which adds it to the view.
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        await MainActor.run {
            previewLayer = layer
            isScanning = true
        }

        // Start the session off the main thread (required by AVFoundation).
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }

        // Restart the session when the app returns from the background.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let session = self.captureSession, !session.isRunning else { return }
            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        }
    }

    func stopScanning() {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
        captureSession = nil

        Task { @MainActor in
            previewLayer = nil
            isScanning = false
            hasScanned = false
            onCodeScanned = nil
        }
    }

    // MARK: - Product Lookup

    func lookupProduct(barcode: String) async throws -> ProductInfo {
        // Check CoreData cache first (valid for 30 days)
        let context = PersistenceController.shared.viewContext
        let request = ProductCache.fetchRequest()
        request.predicate = NSPredicate(format: "barcode == %@", barcode)
        request.fetchLimit = 1
        if let cached = (try? context.fetch(request))?.first,
           let cachedAt = cached.cachedAt,
           Date().timeIntervalSince(cachedAt) < 30 * 24 * 3600 {
            let info = ProductInfo(
                name: cached.productName ?? NSLocalizedString("unnamed_item", comment: ""),
                brand: cached.brand,
                quantity: cached.quantity,
                categories: cached.categories,
                imageUrl: cached.imageURL
            )
            await MainActor.run { self.productInfo = info }
            return info
        }

        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else { throw BarcodeError.invalidBarcode }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BarcodeError.networkError
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(OpenFoodFactsResponse.self, from: data)

        guard apiResponse.status == 1, let product = apiResponse.product else {
            throw BarcodeError.productNotFound
        }

        let info = ProductInfo(
            name: product.productName ?? product.productNameEn ?? NSLocalizedString("unnamed_item", comment: ""),
            brand: product.brands,
            quantity: product.quantity,
            categories: product.categories,
            imageUrl: product.imageFrontUrl
        )

        // Persist to cache
        await MainActor.run {
            let cache: ProductCache
            if let existing = (try? context.fetch(request))?.first {
                cache = existing
            } else {
                cache = ProductCache(context: context)
                cache.barcode = barcode
            }
            cache.productName = info.name
            cache.brand = info.brand
            cache.quantity = info.quantity
            cache.categories = info.categories
            cache.imageURL = info.imageUrl
            cache.cachedAt = Date()
            try? context.save()

            self.productInfo = info
        }
        return info
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeService: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first,
              let readable = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readable.stringValue else {
            return
        }

        hasScanned = true

        // Haptic + system vibration feedback on successful scan.
        UINotificationFeedbackGenerator().notificationOccurred(.success)

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
            return NSLocalizedString("error_camera_denied", comment: "")
        case .noCameraAvailable:
            return NSLocalizedString("error_no_camera", comment: "")
        case .inputError, .outputError:
            return NSLocalizedString("error_camera_setup", comment: "")
        case .invalidBarcode:
            return NSLocalizedString("error_invalid_barcode", comment: "")
        case .networkError:
            return NSLocalizedString("error_network", comment: "")
        case .productNotFound:
            return NSLocalizedString("error_product_not_found", comment: "")
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
