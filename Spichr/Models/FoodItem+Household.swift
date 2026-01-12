//
//  FoodItem+Household.swift
//  Spichr - REWRITTEN FOR THREAD SAFETY
//
//  Created by Sebastian Skerski
//

import Foundation
import CoreData

extension FoodItem {
    
    // householdID wird von CoreData generiert (siehe .xcdatamodeld)
    // KEINE manuelle Deklaration nötig!
    
    /// Setzt householdID automatisch beim Erstellen
    /// CoreData ruft dies im ManagedObjectContext auf - immer thread-safe
    nonisolated public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // CoreData Context garantiert Thread-Safety
        // Wir nutzen setValue für Key-Value Coding (KVC) um MainActor zu umgehen
        if self.value(forKey: "householdID") == nil {
            // Thread-safe UserDefaults access
            if let idString = UserDefaults.standard.string(forKey: "householdID"),
               let id = UUID(uuidString: idString) {
                self.setValue(id, forKey: "householdID")
            } else {
                // Erstelle neue ID
                let newID = UUID()
                UserDefaults.standard.set(newID.uuidString, forKey: "householdID")
                self.setValue(newID, forKey: "householdID")
            }
        }
    }
}

// MARK: - HouseholdManager Extension
// Diese Extension ist für explizite Aufrufe, NICHT für awakeFromInsert

extension HouseholdManager {
    
    /// Aktuelle Household UUID
    /// ⚠️ Diese Methode ist @MainActor isolated!
    /// Nur von Main Thread aufrufen!
    func getCurrentHouseholdID() -> UUID {
        // Lade oder erstelle Household ID
        if let idString = UserDefaults.standard.string(forKey: "householdID"),
           let id = UUID(uuidString: idString) {
            return id
        }
        
        // Erstelle neue ID
        let newID = UUID()
        UserDefaults.standard.set(newID.uuidString, forKey: "householdID")
        return newID
    }
}
