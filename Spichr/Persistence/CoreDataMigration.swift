//
//  CoreData Migration Guide
//  Spichr v2.0 → v2.1
//
//  WICHTIG: Lightweight Migration wird automatisch durchgeführt!
//

import CoreData

/*
 ÄNDERUNGEN im CoreData Model:
 
 FoodItem Entity:
 + householdID: UUID? (optional, neu)
 
 Diese Änderung ist "lightweight" weil:
 - Neues Attribut ist optional
 - Keine bestehenden Attribute geändert
 - Keine Relationen betroffen
 
 CoreData führt automatisch die Migration durch!
 */

// MARK: - Migration Optionen (bereits in PersistenceController)

/*
 // In PersistenceController.swift - Zeile 69:
 
 container.loadPersistentStores { storeDescription, error in
     if let error = error as NSError? {
         // Lightweight Migration funktioniert automatisch!
         // Kein Code-Change erforderlich
     }
 }
 
 CoreData erkennt:
 1. Neues optionales Attribut (householdID)
 2. Führt automatisch Lightweight Migration durch
 3. Bestehende Items: householdID = nil
 4. Neue Items: householdID wird gesetzt via awakeFromInsert()
 */

// MARK: - Post-Migration Setup
// NOTE: migrateOldItemsToDefaultHousehold() ist in PersistenceController.swift definiert

// MARK: - Usage

/*
 // In SpichrApp.swift - nach App-Start:
 
 init() {
     // Führe Migration einmalig durch
     if !UserDefaults.standard.bool(forKey: "hasRunMigrationV2") {
         PersistenceController.shared.migrateOldItemsToDefaultHousehold()
         UserDefaults.standard.set(true, forKey: "hasRunMigrationV2")
     }
 }
 */

// MARK: - Testing

/*
 Test-Szenarien:
 
 1. Neue Installation:
    ✅ Alle Items bekommen automatisch householdID
 
 2. Update von v2.0:
    ✅ Lightweight Migration läuft automatisch
    ✅ Alte Items: householdID = nil
    ✅ Migration Script setzt Default Household
    ✅ Neue Items: householdID automatisch gesetzt
 
 3. Nach Migration:
    ✅ Alle Items haben householdID
    ✅ Sharing funktioniert vollständig
    ✅ Items können nach Household gefiltert werden
 */
