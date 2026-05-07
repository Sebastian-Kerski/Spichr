//
//  FoodItem+Extensions.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Foundation
import SwiftUI

// MARK: - ExpirationStatus Enum

enum ExpirationStatus: Equatable {
    case expired           // Abgelaufen
    case expiringToday    // Läuft heute ab
    case critical         // 1-2 Tage
    case warning          // 3-7 Tage
    case approaching      // 8-30 Tage
    case fresh            // >30 Tage
    case unknown          // Kein Datum
}

// MARK: - FoodItem Extensions

extension FoodItem {
    
    // MARK: - Unwrapped Properties
    
    var unwrappedName: String {
        name ?? NSLocalizedString("unnamed_item", comment: "Unnamed Item")
    }
    
    var unwrappedQuantity: String {
        quantity ?? ""
    }
    
    var unwrappedLocation: String {
        location ?? ""
    }
    
    var unwrappedStore: String {
        store ?? ""
    }
    
    var unwrappedBarcode: String {
        barcode ?? ""
    }
    
    // MARK: - Expiration Calculations
    
    /// Das effektive Ablaufdatum (berücksichtigt "geöffnet"-Status)
    var effectiveExpirationDate: Date? {
        // Wenn geöffnet und shelfLifeAfterOpeningDays > 0
        if let openedDate = openedDate, shelfLifeAfterOpeningDays > 0 {
            let calculatedDate = Calendar.current.date(
                byAdding: .day,
                value: Int(shelfLifeAfterOpeningDays),
                to: openedDate
            )
            
            // Nimm das frühere Datum (geöffnet oder Original-MHD)
            if let originalDate = expirationDate {
                return min(calculatedDate ?? originalDate, originalDate)
            }
            return calculatedDate
        }
        
        return expirationDate
    }
    
    /// Tage bis zum Ablauf (negativ = abgelaufen)
    var daysUntilExpiration: Int? {
        guard let expirationDate = effectiveExpirationDate else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiration = calendar.startOfDay(for: expirationDate)
        
        let components = calendar.dateComponents([.day], from: today, to: expiration)
        return components.day
    }
    
    /// Status der Haltbarkeit
    var expirationStatus: ExpirationStatus {
        guard let days = daysUntilExpiration else { return .unknown }
        
        switch days {
        case ..<0:
            return .expired
        case 0:
            return .expiringToday
        case 1...2:
            return .critical
        case 3...7:
            return .warning
        case 8...30:
            return .approaching
        default:
            return .fresh
        }
    }
    
    /// Display-Text für Ablaufdatum
    var expirationDisplayText: String {
        guard let days = daysUntilExpiration else {
            return NSLocalizedString("no_expiration_date", comment: "No date")
        }
        
        switch days {
        case ..<0:
            let absDays = abs(days)
            if absDays == 1 {
                return NSLocalizedString("expired_yesterday", comment: "Expired yesterday")
            } else {
                return String(format: NSLocalizedString("expired_days_ago", comment: "Expired %d days ago"), absDays)
            }
        case 0:
            return NSLocalizedString("expires_today", comment: "Expires today!")
        case 1:
            return NSLocalizedString("expires_tomorrow", comment: "Expires tomorrow")
        default:
            return String(format: NSLocalizedString("expires_in_days", comment: "Expires in %d days"), days)
        }
    }
    
    /// Formatiertes Ablaufdatum
    var formattedExpirationDate: String? {
        guard let date = effectiveExpirationDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.string(from: date)
    }
    
    // MARK: - Opened Status
    
    /// Ist das Produkt geöffnet?
    var isOpened: Bool {
        openedDate != nil
    }
    
    /// Tage seit Öffnung
    var daysSinceOpened: Int? {
        guard let openedDate = openedDate else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let opened = calendar.startOfDay(for: openedDate)
        
        let components = calendar.dateComponents([.day], from: opened, to: today)
        return components.day
    }
    
    /// Verbleibende Tage nach Öffnung
    var remainingDaysAfterOpening: Int? {
        guard let daysSinceOpened = daysSinceOpened, shelfLifeAfterOpeningDays > 0 else {
            return nil
        }
        
        return Int(shelfLifeAfterOpeningDays) - daysSinceOpened
    }
    
    // MARK: - Validation
    
    /// Hat das Item alle notwendigen Informationen?
    var isValid: Bool {
        !unwrappedName.isEmpty
    }
    
    // MARK: - Display Helpers
    
    /// Vollständiger Location-String mit Icon
    var locationWithIcon: String {
        if unwrappedLocation.isEmpty {
            return NSLocalizedString("no_location", comment: "No location")
        }
        return "📍 \(unwrappedLocation)"
    }
    
    /// Store mit Icon
    var storeWithIcon: String {
        if unwrappedStore.isEmpty {
            return NSLocalizedString("no_store", comment: "No store")
        }
        return "🏪 \(unwrappedStore)"
    }
    
    /// Kurzbeschreibung für Notifications
    var notificationText: String {
        var text = unwrappedName
        if !unwrappedQuantity.isEmpty {
            text += " (\(unwrappedQuantity))"
        }
        return text
    }
    
    // MARK: - CloudKit Sync
    
    /// CloudKit record name (stored in shareReference field)
    var ckRecordName: String? {
        get { shareReference }
        set { shareReference = newValue }
    }
}
