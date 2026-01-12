//
//  PersistenceController.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import Combine
import CoreData
import CloudKit
import os

/// Manages CoreData stack with CloudKit sync
final class PersistenceController: ObservableObject {
    @Published var isReady: Bool = false
    private var hasStarted: Bool = false
    
    private let logger = Logger(subsystem: "com.de.SkerskiDev.Spichr", category: "Persistence")
    
    // MARK: - Singleton
    
    static let shared = PersistenceController()
    
    // MARK: - Preview Support
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Create sample data for previews
        for i in 0..<10 {
            let item = FoodItem(context: viewContext)
            item.id = UUID()
            item.name = "Sample Item \(i)"
            item.quantity = "\(i + 1)"
            item.location = ["Kühlschrank", "Gefrierschrank", "Vorratsschrank"].randomElement()
            item.isInStock = i % 2 == 0
            item.expirationDate = Calendar.current.date(byAdding: .day, value: Int.random(in: -5...60), to: Date())
            item.lastModified = Date()
        }
        
        try? viewContext.save()
        return controller
    }()
    
    // MARK: - Properties
    
    let container: NSPersistentCloudKitContainer
    
    // MARK: - Initialization
    
    init(inMemory: Bool = false) {
        logger.info("Initializing PersistenceController (inMemory: \(inMemory, privacy: .public))")
        let loadStart = Date()
        // Container name must match Xcode's .xcdatamodeld filename
        container = NSPersistentCloudKitContainer(name: "Spichr")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // CloudKit Configuration
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }
            
            // Enable persistent history tracking (required for CloudKit)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // ✅ CRITICAL: CloudKit Sharing Configuration
            let containerIdentifier = "iCloud.com.de.SkerskiDev.FoodGuard"
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
            
            // ✅ Enable database scope for sharing
            cloudKitOptions.databaseScope = .private
            
            description.cloudKitContainerOptions = cloudKitOptions
            
            logger.info("✅ CloudKit Sharing configured for container: \(containerIdentifier)")
        }
        
        if inMemory {
            container.loadPersistentStores { storeDescription, error in
                if let error = error as NSError? {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
                let elapsed = Date().timeIntervalSince(loadStart)
                self.logger.info("In-memory persistent stores loaded in \(String(format: "%.2f", elapsed))s")
                Task { @MainActor in
                    self.isReady = true
                }
            }
        } else {
            // Defer loading persistent stores to start()
        }
        
        // Automatically merge changes from CloudKit
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Observe remote changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }
    
    @MainActor
    func start() async {
        if hasStarted { return }
        hasStarted = true
        logger.info("Starting persistent stores load")
        let loadStart = Date()
        await withCheckedContinuation { continuation in
            container.loadPersistentStores { storeDescription, error in
                if let error = error as NSError? {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
                let elapsed = Date().timeIntervalSince(loadStart)
                self.logger.info("Persistent stores loaded in \(String(format: "%.2f", elapsed))s")
                self.isReady = true
                continuation.resume()
            }
        }
    }
    
    // MARK: - Context Management
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Save Operations
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - CloudKit Remote Changes
    
    @objc private func handleRemoteChange(_ notification: Notification) {
        // Notification posted when CloudKit sync occurs
        // Must publish on main thread as objectWillChange requires @MainActor
        Task { @MainActor in
            objectWillChange.send()
        }
    }
    
    // MARK: - Batch Operations
    
    func deleteAllData() async throws {
        let context = newBackgroundContext()
        
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "FoodItem")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
            let changes = [NSDeletedObjectsKey: objectIDArray]
            
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
        }
    }
    
    // MARK: - Sharing Support
    
    /// Checks if sharing is supported (requires iCloud account)
    func canShare() -> Bool {
        // Check CloudKit account status
        // This is a simplified check - in production you'd check CKContainer.accountStatus
        return true
    }
    
    /// Prepares an item for sharing
    func prepareShare(_ item: FoodItem) -> CKShare? {
        // This will be implemented with CloudKit sharing functionality
        // For now, return nil - we'll implement this in Phase 2
        return nil
    }
    
    // MARK: - Data Migration
    
    /// Migriert alte Items zum Default Household (einmalig beim ersten Start nach Update)
    func migrateOldItemsToDefaultHousehold() {
        let context = newBackgroundContext()
        
        // WICHTIG: Capture householdID BEFORE entering background context!
        // HouseholdManager.shared ist @MainActor isolated
        Task { @MainActor in
            let defaultHouseholdID = HouseholdManager.shared.getCurrentHouseholdID()
            
            context.perform {
                let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
                fetchRequest.predicate = NSPredicate(format: "householdID == nil")
                
                do {
                    let itemsWithoutHousehold = try context.fetch(fetchRequest)
                    
                    if !itemsWithoutHousehold.isEmpty {
                        print("🔄 Migrating \(itemsWithoutHousehold.count) items to default household")
                        
                        for item in itemsWithoutHousehold {
                            item.householdID = defaultHouseholdID
                        }
                        
                        try context.save()
                        print("✅ Migration complete!")
                    }
                } catch {
                    print("❌ Migration failed: \(error)")
                }
            }
        }
    }
    
    /// Fallback to an in-memory persistent store if CloudKit-backed loading takes too long.
    @MainActor
    func fallbackToInMemoryIfNeeded() {
        guard !isReady else { return }
        logger.info("Falling back to in-memory persistent store")
        // Reconfigure the first store description to use /dev/null
        if let description = container.persistentStoreDescriptions.first {
            description.url = URL(fileURLWithPath: "/dev/null")
            description.cloudKitContainerOptions = nil
        }
        let loadStart = Date()
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Fallback load error: \(error), \(error.userInfo)")
            }
            let elapsed = Date().timeIntervalSince(loadStart)
            self.logger.info("In-memory fallback store loaded in \(String(format: "%.2f", elapsed))s")
            self.isReady = true
        }
    }
    
    // MARK: - CloudKit Sharing
    
    /// Shares items using NSPersistentCloudKitContainer's built-in sharing
    @MainActor
    func shareItems(_ items: [FoodItem]) async throws -> (CKShare, CKContainer) {
        logger.info("🔵 Sharing \(items.count) items using CoreData CloudKit...")
        
        guard !items.isEmpty else {
            throw NSError(domain: "Spichr", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "No items to share"])
        }
        
        let ckContainer = CKContainer(identifier: "iCloud.com.de.SkerskiDev.FoodGuard")
        
        // Use the first item as root for the share
        let rootItem = items[0]
        
        // Step 1: Create share with first item
        let (initialShare, _): (CKShare, CKContainer) = try await withCheckedThrowingContinuation { continuation in
            container.share([rootItem], to: nil) { objectIDs, share, ckContainer, error in
                if let error = error {
                    self.logger.error("❌ Share creation failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let share = share, let ckContainer = ckContainer else {
                    let error = NSError(domain: "Spichr", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Share or container is nil"])
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: (share, ckContainer))
            }
        }
        
        logger.info("✅ Initial share created")
        
        // Step 2: Fetch the share from CloudKit to get latest version
        let database = ckContainer.privateCloudDatabase
        let share = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare, Error>) in
            database.fetch(withRecordID: initialShare.recordID) { record, error in
                if let error = error {
                    self.logger.error("❌ Failed to fetch share: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let fetchedShare = record as? CKShare else {
                    let error = NSError(domain: "Spichr", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Fetched record is not a CKShare"])
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: fetchedShare)
            }
        }
        
        logger.info("✅ Share fetched from CloudKit")
        
        // Step 3: Configure share permissions
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = "Spichr Household"
        
        if #available(iOS 15.0, *) {
            share[CKShare.SystemFieldKey.shareType] = "com.de.SkerskiDev.FoodGuard.household"
        }
        
        logger.info("✅ Share configured with READ/WRITE permissions")
        
        // Step 4: Save the updated share back to CloudKit
        let savedShare = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare, Error>) in
            database.save(share) { savedRecord, error in
                if let error = error {
                    self.logger.error("❌ Failed to save share: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let savedRecord = savedRecord as? CKShare else {
                    let error = NSError(domain: "Spichr", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Saved record is not a CKShare"])
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: savedRecord)
            }
        }
        
        logger.info("✅ Share SAVED to CloudKit with READ/WRITE permissions")
        logger.info("✅ Share URL: \(savedShare.url?.absoluteString ?? "no URL")")
        
        // Step 5: Add remaining items to the share (if more than 1)
        if items.count > 1 {
            logger.info("🔵 Adding \(items.count - 1) more items to share...")
            
            for item in items.dropFirst() {
                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        container.share([item], to: savedShare) { objectIDs, updatedShare, ckContainer, error in
                            if let error = error {
                                self.logger.error("❌ Failed to add item to share: \(error.localizedDescription)")
                                continuation.resume(throwing: error)
                                return
                            }
                            continuation.resume()
                        }
                    }
                } catch {
                    logger.error("❌ Failed to add item '\(item.name ?? "unknown")' to share: \(error.localizedDescription)")
                    // Continue with other items
                }
            }
            
            logger.info("✅ All items added to share")
        }
        
        return (savedShare, ckContainer)
    }
    
    /// Checks if an item is shared
    func isShared(object: NSManagedObject) -> Bool {
        return (try? share(for: object)) != nil
    }
    
    /// Gets the share for an object
    func share(for object: NSManagedObject) throws -> CKShare? {
        let sharesDict = try container.fetchShares(matching: [object.objectID])
        if let share = sharesDict[object.objectID] {
            return share
        } else {
            logger.info("No share found for objectID: \(object.objectID)")
            return nil
        }
    }
    
    /// Stops sharing an object
    @MainActor
    func stopSharing(object: NSManagedObject) throws {
        logger.info("🔴 Stopping share for object...")
        
        guard let share = try share(for: object) else {
            logger.info("⚠️ No share found for object")
            return
        }
        
        // Delete the share record from CloudKit
        let ckContainer = CKContainer(identifier: "iCloud.com.de.SkerskiDev.FoodGuard")
        Task {
            do {
                try await ckContainer.privateCloudDatabase.deleteRecord(withID: share.recordID)
                logger.info("✅ Share stopped")
            } catch {
                logger.error("❌ Failed to stop sharing: \(error.localizedDescription)")
            }
        }
    }
}

