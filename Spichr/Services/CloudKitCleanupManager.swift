//
//  CloudKitCleanupManager.swift
//  Spichr
//
//  Behebt orphaned share references und synchronisiert das Schema
//

import Foundation
import CloudKit

@MainActor
final class CloudKitCleanupManager {
    
    private let container = CKContainer(identifier: "iCloud.com.de.SkerskiDev.FoodGuard")
    
    // MARK: - Hauptfunktion: Cleanup durchführen
    
    /// Führt komplettes Cleanup durch
    func performFullCleanup() async throws {
        print("🔧 Starting CloudKit cleanup...")
        
        // 1. Orphaned Shares finden und entfernen
        try await cleanOrphanedShares()
        
        // 2. Records ohne valide Share-Referenzen finden
        try await cleanOrphanedRecordReferences()
        
        // 3. UserDefaults zurücksetzen
        cleanUserDefaults()
        
        print("✅ Cleanup completed successfully!")
    }
    
    // MARK: - 1. Orphaned Shares entfernen
    
    /// Findet und entfernt Shares ohne zugehörige Root-Records
    private func cleanOrphanedShares() async throws {
        print("🔍 Checking for orphaned shares...")
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "cloudkit.share", predicate: predicate)
        
        do {
            let (matchResults, _) = try await container.privateCloudDatabase.records(matching: query)
            
            var orphanedShares: [CKRecord.ID] = []
            
            for (recordID, result) in matchResults {
                if case .success(let share) = result, let ckShare = share as? CKShare {
                    // Prüfe ob Root-Record existiert
                    let rootRecordID = ckShare.recordID
                    
                    do {
                        _ = try await container.privateCloudDatabase.record(for: rootRecordID)
                        print("✅ Share \(recordID.recordName) has valid root record")
                    } catch {
                        print("⚠️ Share \(recordID.recordName) is orphaned - marking for deletion")
                        orphanedShares.append(recordID)
                    }
                }
            }
            
            // Orphaned Shares löschen
            if !orphanedShares.isEmpty {
                print("🗑️ Deleting \(orphanedShares.count) orphaned shares...")
                let (_, deleteResults) = try await container.privateCloudDatabase.modifyRecords(
                    saving: [],
                    deleting: orphanedShares
                )
                
                for (recordID, result) in deleteResults {
                    switch result {
                    case .success:
                        print("✅ Deleted orphaned share: \(recordID.recordName)")
                    case .failure(let error):
                        print("⚠️ Could not delete share \(recordID.recordName): \(error)")
                    }
                }
            } else {
                print("✅ No orphaned shares found")
            }
            
        } catch {
            print("⚠️ Error during share cleanup: \(error)")
            // Nicht fatal - weitermachen
        }
    }
    
    // MARK: - 2. Record-Referenzen bereinigen
    
    /// Bereinigt Records mit ungültigen Share-Referenzen
    private func cleanOrphanedRecordReferences() async throws {
        print("🔍 Checking for records with invalid share references...")
        
        // Prüfe Household Records
        try await cleanRecordType("Household")
        
        // Prüfe SharedHousehold Records (falls vorhanden)
        try await cleanRecordType("SharedHousehold")
        
        // Prüfe FoodItem Records
        try await cleanRecordType("FoodItem")
    }
    
    private func cleanRecordType(_ recordType: String) async throws {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            let (matchResults, _) = try await container.privateCloudDatabase.records(matching: query)
            
            var recordsToUpdate: [CKRecord] = []
            
            for (recordID, result) in matchResults {
                if case .success(let record) = result {
                    // Prüfe ob Parent-Share existiert
                    if let parent = record.parent {
                        do {
                            _ = try await container.privateCloudDatabase.record(for: parent.recordID)
                            print("✅ \(recordType) \(recordID.recordName) has valid parent")
                        } catch {
                            print("⚠️ \(recordType) \(recordID.recordName) has orphaned parent reference - removing")
                            record.parent = nil
                            recordsToUpdate.append(record)
                        }
                    }
                }
            }
            
            // Records aktualisieren
            if !recordsToUpdate.isEmpty {
                print("📝 Updating \(recordsToUpdate.count) \(recordType) records...")
                
                // In Batches von 100 verarbeiten
                let batchSize = 100
                for i in stride(from: 0, to: recordsToUpdate.count, by: batchSize) {
                    let end = min(i + batchSize, recordsToUpdate.count)
                    let batch = Array(recordsToUpdate[i..<end])
                    
                    do {
                        _ = try await container.privateCloudDatabase.modifyRecords(saving: batch, deleting: [])
                        print("✅ Updated batch \(i/batchSize + 1)")
                    } catch {
                        print("⚠️ Error updating batch: \(error)")
                    }
                }
            } else {
                print("✅ No \(recordType) records need updating")
            }
            
        } catch {
            print("⚠️ Error checking \(recordType): \(error)")
            // Nicht fatal
        }
    }
    
    // MARK: - 3. UserDefaults bereinigen
    
    private func cleanUserDefaults() {
        print("🧹 Cleaning UserDefaults...")
        
        let keysToRemove = [
            "cloudkit_share_record",
            "cloudkit_share_url",
            "cloudkit_zone_name",
            "cloudkit_is_sharing",
            "shareRecordName",
            "shareURL",
            "householdIsShared"
        ]
        
        for key in keysToRemove {
            if UserDefaults.standard.object(forKey: key) != nil {
                print("🗑️ Removing key: \(key)")
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        UserDefaults.standard.synchronize()
        print("✅ UserDefaults cleaned")
    }
    
    // MARK: - 4. Vollständiger Reset (Nuclear Option)
    
    /// VORSICHT: Löscht ALLE Daten in CloudKit
    /// Nur für Development/Testing verwenden!
    func performNuclearReset() async throws {
        print("☢️ WARNING: Performing nuclear reset...")
        print("This will delete ALL CloudKit data!")
        
        // Alle Record Types löschen
        let recordTypes = ["Household", "SharedHousehold", "FoodItem", "FoodGuardList", "SpichrInventory", "Users"]
        
        for recordType in recordTypes {
            print("🗑️ Deleting all \(recordType) records...")
            try await deleteAllRecords(ofType: recordType)
        }
        
        // Shares löschen
        print("🗑️ Deleting all shares...")
        try await deleteAllShares()
        
        // UserDefaults löschen
        cleanUserDefaults()
        
        print("☢️ Nuclear reset completed!")
    }
    
    private func deleteAllRecords(ofType recordType: String) async throws {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        let (matchResults, _) = try await container.privateCloudDatabase.records(matching: query)
        let recordIDs = matchResults.compactMap { (key, result) -> CKRecord.ID? in
            return key
        }
        
        if !recordIDs.isEmpty {
            print("Found \(recordIDs.count) \(recordType) records to delete")
            
            // In Batches löschen
            let batchSize = 100
            for i in stride(from: 0, to: recordIDs.count, by: batchSize) {
                let end = min(i + batchSize, recordIDs.count)
                let batch = Array(recordIDs[i..<end])
                _ = try await container.privateCloudDatabase.modifyRecords(saving: [], deleting: batch)
            }
        }
    }
    
    private func deleteAllShares() async throws {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "cloudkit.share", predicate: predicate)
        
        let (matchResults, _) = try await container.privateCloudDatabase.records(matching: query)
        let shareIDs = matchResults.compactMap { (key, result) -> CKRecord.ID? in
            return key
        }
        
        if !shareIDs.isEmpty {
            print("Found \(shareIDs.count) shares to delete")
            _ = try await container.privateCloudDatabase.modifyRecords(saving: [], deleting: shareIDs)
        }
    }
    
    // MARK: - 5. Diagnose-Report
    
    /// Erstellt einen Diagnose-Report
    func generateDiagnosticReport() async -> String {
        var report = "=== CloudKit Diagnostic Report ===\n\n"
        
        // UserDefaults prüfen
        report += "UserDefaults:\n"
        let keys = [
            "cloudkit_share_record", "cloudkit_share_url", "cloudkit_zone_name",
            "cloudkit_is_sharing", "shareRecordName", "shareURL", "householdIsShared"
        ]
        for key in keys {
            if let value = UserDefaults.standard.object(forKey: key) {
                report += "  \(key): \(value)\n"
            }
        }
        report += "\n"
        
        // Records zählen
        let recordTypes = ["Household", "SharedHousehold", "FoodItem", "cloudkit.share"]
        report += "Record Counts:\n"
        
        for recordType in recordTypes {
            let count = await countRecords(ofType: recordType)
            report += "  \(recordType): \(count)\n"
        }
        
        return report
    }
    
    private func countRecords(ofType recordType: String) async -> Int {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            let (matchResults, _) = try await container.privateCloudDatabase.records(matching: query)
            return matchResults.count
        } catch {
            return -1
        }
    }
}

// MARK: - Convenience Extension

extension CloudKitCleanupManager {
    
    /// Quick fix für den spezifischen Fehler im Screenshot
    func quickFixOrphanedShareError() async throws {
        print("🔧 Quick fix for orphaned share error...")
        
        // 1. Bereinige alle Share-Referenzen in Household Records
        try await cleanRecordType("Household")
        
        // 2. Lösche UserDefaults
        cleanUserDefaults()
        
        print("✅ Quick fix completed!")
        print("ℹ️ Please restart the app")
    }
}
