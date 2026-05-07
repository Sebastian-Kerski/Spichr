//
//  SpotlightService.swift
//  Spichr
//

import CoreSpotlight
import CoreData
import UIKit
import os

final class SpotlightService {

    static let shared = SpotlightService()
    private let domainID = "com.de.SkerskiDev.FoodGuard.items"
    private let logger = Logger(subsystem: "com.de.SkerskiDev.Spichr", category: "Spotlight")
    private init() {}

    func indexItem(_ item: FoodItem) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = item.unwrappedName
        var parts: [String] = []
        if !item.unwrappedLocation.isEmpty { parts.append(item.unwrappedLocation) }
        if !item.unwrappedQuantity.isEmpty { parts.append(item.unwrappedQuantity) }
        if let days = item.daysUntilExpiration {
            if days < 0 {
                parts.append(NSLocalizedString("status_expired", comment: ""))
            } else if days == 0 {
                parts.append(NSLocalizedString("expires_today", comment: ""))
            } else {
                parts.append(item.expirationDisplayText)
            }
        }
        attributeSet.contentDescription = parts.joined(separator: " · ")
        attributeSet.keywords = [item.unwrappedName, item.unwrappedLocation, item.unwrappedStore].filter { !$0.isEmpty }

        let searchItem = CSSearchableItem(
            uniqueIdentifier: item.objectID.uriRepresentation().absoluteString,
            domainIdentifier: domainID,
            attributeSet: attributeSet
        )
        searchItem.expirationDate = .distantFuture

        CSSearchableIndex.default().indexSearchableItems([searchItem]) { error in
            if let error { self.logger.error("Spotlight index error: \(error.localizedDescription)") }
        }
    }

    func removeItem(objectID: NSManagedObjectID) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [objectID.uriRepresentation().absoluteString]
        ) { error in
            if let error { self.logger.error("Spotlight delete error: \(error.localizedDescription)") }
        }
    }

    func reindexAll(_ items: [FoodItem]) {
        CSSearchableIndex.default().deleteAllSearchableItems { [weak self] _ in
            guard let self else { return }
            let stockItems = items.filter { $0.isInStock }
            stockItems.forEach { self.indexItem($0) }
        }
    }
}
