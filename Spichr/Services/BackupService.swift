//
//  BackupService.swift
//  Spichr
//

import Foundation
import CoreData

struct SpichrBackup: Codable {
    let version: Int
    let exportedAt: Date
    let items: [BackupItem]
}

struct BackupItem: Codable {
    let id: String?
    let name: String
    let quantity: String?
    let location: String?
    let store: String?
    let barcode: String?
    let category: String?
    let isInStock: Bool
    let expirationDate: Date?
    let openedDate: Date?
    let shelfLifeAfterOpeningDays: Int
    let productImageURL: String?
}

final class BackupService {

    static let shared = BackupService()
    private let repository = FoodItemRepository()

    private init() {}

    // MARK: - Export

    func exportJSON() throws -> URL {
        let items = repository.fetchAllItems().map { item in
            BackupItem(
                id: item.id?.uuidString,
                name: item.unwrappedName,
                quantity: item.quantity,
                location: item.location,
                store: item.store,
                barcode: item.barcode,
                category: item.category,
                isInStock: item.isInStock,
                expirationDate: item.expirationDate,
                openedDate: item.openedDate,
                shelfLifeAfterOpeningDays: Int(item.shelfLifeAfterOpeningDays),
                productImageURL: item.productImageURL
            )
        }

        let backup = SpichrBackup(version: 1, exportedAt: Date(), items: items)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backup)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "spichr_backup_\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    // MARK: - Import

    func importJSON(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(SpichrBackup.self, from: data)

        var imported = 0
        for backupItem in backup.items {
            repository.createItem(
                name: backupItem.name,
                quantity: backupItem.quantity,
                location: backupItem.location,
                store: backupItem.store,
                expirationDate: backupItem.expirationDate,
                barcode: backupItem.barcode,
                category: backupItem.category,
                isInStock: backupItem.isInStock,
                productImageURL: backupItem.productImageURL
            )
            imported += 1
        }

        return imported
    }
}
