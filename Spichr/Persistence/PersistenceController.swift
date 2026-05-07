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
            // ✅ FIX: Two stores required for CloudKit Sharing between different Apple IDs.
            // - Private store: user's own data (.private database scope)
            // - Shared store:  data shared by other Apple IDs (.shared database scope)
            // Without the shared store, accepted share invitations have nowhere to land.
            let containerIdentifier = AppConstants.CloudKit.containerIdentifier
            let storeDir = NSPersistentContainer.defaultDirectoryURL()

            // Private store (Default configuration)
            let privateStoreURL = storeDir.appendingPathComponent("Spichr.sqlite")
            let privateDesc = NSPersistentStoreDescription(url: privateStoreURL)
            privateDesc.configuration = "Default"
            privateDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateDesc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
            privateOptions.databaseScope = .private
            privateDesc.cloudKitContainerOptions = privateOptions

            // Shared store (Shared configuration)
            let sharedStoreURL = storeDir.appendingPathComponent("Spichr-Shared.sqlite")
            let sharedDesc = NSPersistentStoreDescription(url: sharedStoreURL)
            sharedDesc.configuration = "Shared"
            sharedDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            sharedDesc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
            sharedOptions.databaseScope = .shared
            sharedDesc.cloudKitContainerOptions = sharedOptions

            container.persistentStoreDescriptions = [privateDesc, sharedDesc]

            logger.info("✅ CloudKit configured: private + shared stores for \(containerIdentifier)")
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // loadPersistentStores calls the completion once per store description.
            // Use a DispatchGroup so we resume only after all stores have loaded.
            let group = DispatchGroup()
            container.persistentStoreDescriptions.forEach { _ in group.enter() }

            container.loadPersistentStores { storeDescription, error in
                defer { group.leave() }
                if let error = error as NSError? {
                    // Shared store failures are non-fatal — the private store is sufficient for basic operation.
                    // This can happen when CloudKit sharing is not yet configured on the device.
                    if storeDescription.configuration?.lowercased() == "shared" {
                        self.logger.error("Shared store failed (non-fatal): \(error.localizedDescription)")
                    } else {
                        fatalError("Private store failed to load: \(error), \(error.userInfo)")
                    }
                } else {
                    self.logger.info("Loaded store: \(storeDescription.url?.lastPathComponent ?? "unknown")")
                }
            }

            group.notify(queue: .main) {
                let elapsed = Date().timeIntervalSince(loadStart)
                self.logger.info("All persistent stores loaded in \(String(format: "%.2f", elapsed))s")
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
                logger.error("Error saving context: \(nsError.localizedDescription)")
            }
        }
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                logger.error("Error saving context: \(nsError.localizedDescription)")
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
            // Scope to the private store only — shared items belong to another user's account
            // and must not be batch-deleted from this device.
            if let privateStore = self.privatePersistentStore {
                fetchRequest.affectedStores = [privateStore]
            }
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
                // Only migrate items in the private store; shared store items carry
                // the owner's householdID and must not be overwritten.
                if let privateStore = self.privatePersistentStore {
                    fetchRequest.affectedStores = [privateStore]
                }

                do {
                    let itemsWithoutHousehold = try context.fetch(fetchRequest)
                    
                    if !itemsWithoutHousehold.isEmpty {
                        self.logger.info("Migrating \(itemsWithoutHousehold.count) items to default household")

                        for item in itemsWithoutHousehold {
                            item.householdID = defaultHouseholdID
                        }

                        try context.save()
                        self.logger.info("Migration complete")
                    }
                } catch {
                    self.logger.error("Migration failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Removes FoodItems from the shared store that have no householdID and no shareReference.
    /// These are orphans left behind when a sharing session ended without a clean CloudKit teardown.
    func removeOrphanedSharedItems() {
        guard let sharedStore = sharedPersistentStore else { return }
        let context = newBackgroundContext()

        context.perform {
            let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
            fetchRequest.predicate = NSPredicate(format: "householdID == nil AND shareReference == nil")
            fetchRequest.affectedStores = [sharedStore]

            do {
                let orphans = try context.fetch(fetchRequest)
                guard !orphans.isEmpty else { return }
                self.logger.info("Removing \(orphans.count) orphaned item(s) from shared store")
                orphans.forEach { context.delete($0) }
                try context.save()
            } catch {
                self.logger.error("Orphan cleanup failed: \(error.localizedDescription)")
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

    /// The owner's private persistent store (.private CloudKit scope, "Default" config).
    var privatePersistentStore: NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores
            .first { $0.configurationName.lowercased() == "default" }
    }

    /// The persistent store that holds data shared by other Apple IDs (.shared scope).
    var sharedPersistentStore: NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores
            .first { $0.configurationName.lowercased() == "shared" }
    }

    /// Accepts a CloudKit share invitation and syncs it into the shared persistent store.
    /// Must be called from the SceneDelegate or with a URL-derived CKShare.Metadata.
    @MainActor
    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {
        guard let sharedStore = sharedPersistentStore else {
            throw NSError(domain: "Spichr", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Shared persistent store not found. Check CloudKit configuration."])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Shares items using NSPersistentCloudKitContainer's built-in sharing
    @MainActor
    func shareItems(_ items: [FoodItem]) async throws -> (CKShare, CKContainer) {
        logger.info("🔵 Sharing \(items.count) items using CoreData CloudKit...")
        
        guard !items.isEmpty else {
            throw NSError(domain: "Spichr", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "No items to share"])
        }
        
        // Use the first item as the root object
        let rootItem = items[0]

        return try await withCheckedThrowingContinuation { continuation in
            container.share([rootItem], to: nil) { _, share, ckContainer, error in
                if let error = error {
                    self.logger.error("❌ Share creation failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let share = share else {
                    let error = NSError(domain: "Spichr", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Share is nil"])
                    continuation.resume(throwing: error)
                    return
                }

                guard let ckContainer = ckContainer else {
                    let error = NSError(domain: "Spichr", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Container is nil"])
                    continuation.resume(throwing: error)
                    return
                }

                // Allow invited participants to both read and write.
                // publicPermission = .none means only explicitly invited people can join,
                // but each participant gets readWrite access via UICloudSharingController.
                share.publicPermission = .none
                for participant in share.participants where participant != share.owner {
                    participant.permission = .readWrite
                }

                self.logger.info("✅ Share created: \(share.url?.absoluteString ?? "no URL")")
                continuation.resume(returning: (share, ckContainer))
            }
        }
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
        let ckContainer = CKContainer(identifier: AppConstants.CloudKit.containerIdentifier)
        Task {
            do {
                try await ckContainer.privateCloudDatabase.deleteRecord(withID: share.recordID)
                self.logger.info("✅ Share stopped")
            } catch {
                self.logger.error("❌ Failed to stop sharing: \(error.localizedDescription)")
            }
        }
    }
}

