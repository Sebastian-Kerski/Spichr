//
//  HouseholdManager.swift
//  Spichr - CoreData CloudKit Sharing Integration
//
//  Created by Sebastian Skerski
//

import Foundation
import CloudKit
import SwiftUI
import CoreData
import Combine
import os

/// Household management with NATIVE CoreData CloudKit Sharing
final class HouseholdManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentHousehold: String = "My Household"
    @Published var isShared: Bool = false
    @Published var isSharing: Bool = false
    @Published var members: [String] = []
    @Published var participants: [CKShare.Participant] = []
    @Published var isLoading: Bool = false
    @Published var shareURL: URL?
    @Published var sharingError: String?
    
    /// Whether the current user is the owner of the share
    var isOwner: Bool {
        isSharing
    }
    
    // MARK: - Singleton
    
    static let shared = HouseholdManager()

    let container = CKContainer(identifier: AppConstants.CloudKit.containerIdentifier)
    var share: CKShare?
    private let logger = Logger(subsystem: "com.de.SkerskiDev.Spichr", category: "Household")

    private init() {
        loadHousehold()
    }
    
    // MARK: - Load & Save
    
    func loadHousehold() {
        currentHousehold = UserDefaults.standard.string(forKey: "householdName") ?? "My Household"
        isShared = UserDefaults.standard.bool(forKey: "householdIsShared")
        members = UserDefaults.standard.stringArray(forKey: "householdMembers") ?? []
        
        // Load share URL if exists
        if let urlString = UserDefaults.standard.string(forKey: "shareURL"),
           let url = URL(string: urlString) {
            shareURL = url
        }
    }
    
    func save() {
        UserDefaults.standard.set(currentHousehold, forKey: "householdName")
        UserDefaults.standard.set(isShared, forKey: "householdIsShared")
        UserDefaults.standard.set(members, forKey: "householdMembers")
        
        if let url = shareURL {
            UserDefaults.standard.set(url.absoluteString, forKey: "shareURL")
        }
    }
    
    // MARK: - SHARE HOUSEHOLD (CoreData Native)
    
    /// Creates a share for all FoodItems using CoreData CloudKit Sharing
    @MainActor
    func shareHousehold() async throws -> CKShare {
        guard !isLoading else {
            logger.warning("Share operation already in progress")
            throw NSError(domain: "Spichr", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Share operation already in progress"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        logger.info("Starting CoreData CloudKit Sharing")
        
        // Check if we already have a share
        if let existingShare = self.share, let existingURL = existingShare.url {
            logger.info("Share already exists: \(existingURL.absoluteString, privacy: .public)")
            return existingShare
        }
        
        // Get all FoodItems from the private store — only items the user owns can be shared.
        let context = PersistenceController.shared.viewContext
        let fetchRequest = FoodItem.fetchRequest()
        if let privateStore = PersistenceController.shared.privatePersistentStore {
            fetchRequest.affectedStores = [privateStore]
        }
        let items = try context.fetch(fetchRequest)

        logger.info("Found \(items.count) items to share")
        
        guard !items.isEmpty else {
            logger.info("No items to share, creating placeholder")
            // Create a placeholder item
            let placeholder = FoodItem(context: context)
            placeholder.id = UUID()
            placeholder.name = "Shared Household"
            placeholder.isInStock = false
            placeholder.lastModified = Date()
            try context.save()
            
            return try await shareItems([placeholder])
        }
        
        do {
            return try await shareItems(items)
        } catch {
            sharingError = error.localizedDescription
            throw error
        }
    }

    @MainActor
    private func shareItems(_ items: [FoodItem]) async throws -> CKShare {
        logger.info("Sharing \(items.count) items using CoreData")
        
        // Use PersistenceController's share function
        let (share, _) = try await PersistenceController.shared.shareItems(items)
        
        guard let shareURL = share.url else {
            throw NSError(domain: "Spichr", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Share has no URL"])
        }
        
        logger.info("Share created successfully")
        logger.info("Share URL: \(shareURL.absoluteString, privacy: .public)")
        
        // Update state
        self.share = share
        self.shareURL = shareURL
        self.isShared = true
        self.isSharing = true
        UserDefaults.standard.set(share.recordID.recordName, forKey: "shareRecordName")
        
        // Update participants
        let currentUser = share.owner
        participants = share.participants.filter { $0 != currentUser }
        
        save()

        // Give CloudKit time to sync zone metadata before the sharing sheet opens.
        // Without this delay UICloudSharingController can show a white screen because
        // the zone's encodedShareAsset is still nil when the controller loads.
        try await Task.sleep(nanoseconds: 1_500_000_000)

        // Notify about sharing status change
        NotificationCenter.default.post(
            name: NSNotification.Name("HouseholdSharingStatusChanged"),
            object: nil
        )

        return share
    }
    
    // MARK: - ACCEPT SHARE

    /// Entry point when the user taps a share link (called from SceneDelegate).
    /// Uses NSPersistentCloudKitContainer so CoreData syncs the shared data automatically.
    @MainActor
    func acceptCloudKitShare(metadata: CKShare.Metadata) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        logger.info("Accepting CloudKit share via CoreData")

        do {
            try await PersistenceController.shared.acceptShareInvitation(from: metadata)
            isShared = true
            isSharing = false
            save()
            logger.info("Share accepted — CoreData will sync shared items automatically")
            NotificationCenter.default.post(
                name: NSNotification.Name("HouseholdSharingStatusChanged"),
                object: nil
            )
        } catch {
            logger.error("Share acceptance failed: \(error.localizedDescription)")
        }
    }

    /// URL-based fallback: fetches CKShare.Metadata from a URL, then delegates
    /// to acceptCloudKitShare(metadata:). Used when the user pastes a share link manually.
    @MainActor
    func acceptShare(url: URL) async throws {
        isLoading = true
        defer { isLoading = false }

        logger.info("Fetching share metadata from URL")
        do {
            let metadata = try await container.shareMetadata(for: url)
            logger.info("Share metadata retrieved")

            // Delegate to the CoreData-aware path
            isLoading = false  // acceptCloudKitShare manages isLoading itself
            await acceptCloudKitShare(metadata: metadata)
            self.shareURL = url
            save()
        } catch {
            sharingError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - STOP SHARING
    
    /// Stops sharing the household
    @MainActor
    func stopSharing() async throws {
        guard isShared else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        logger.info("Stopping share")
        
        // Fetch from private store — stopSharing(object:) needs an item the user owns;
        // shared-store items belong to another account and cannot have their share removed here.
        let context = PersistenceController.shared.viewContext
        let fetchRequest = FoodItem.fetchRequest()
        if let privateStore = PersistenceController.shared.privatePersistentStore {
            fetchRequest.affectedStores = [privateStore]
        }
        let items = try context.fetch(fetchRequest)

        // Stop sharing using CoreData
        if let firstItem = items.first {
            try PersistenceController.shared.stopSharing(object: firstItem)
        }
        
        // Clear state
        self.share = nil
        self.shareURL = nil
        self.isShared = false
        self.isSharing = false
        self.members = []
        self.participants = []
        
        save()
        
        logger.info("Sharing stopped")
    }
    
    // MARK: - Load Participants
    
    /// Loads/refreshes the share and participants list.
    /// Attempts to resolve an existing CKShare from Core Data if needed.
    @MainActor
    func loadParticipants() async throws {
        // If we already have a share, just refresh participants from it
        if let share = self.share {
            // Exclude the owner from the visible participants list
            self.participants = share.participants.filter { $0 != share.owner }
            return
        }
        
        // Try to resolve a share from any existing FoodItem in the private store.
        // CKShares only exist on objects the current user owns; items in the shared store
        // are owned by another account and will never have a fetchable CKShare here.
        let context = PersistenceController.shared.viewContext
        let fetchRequest = FoodItem.fetchRequest()
        if let privateStore = PersistenceController.shared.privatePersistentStore {
            fetchRequest.affectedStores = [privateStore]
        }

        do {
            let items = try context.fetch(fetchRequest)
            if let firstItem = items.first, let resolvedShare = try PersistenceController.shared.share(for: firstItem) {
                self.share = resolvedShare
                self.participants = resolvedShare.participants.filter { $0 != resolvedShare.owner }
                self.isShared = true
                // If we can resolve a share from our own items, consider this device as sharing-capable
                self.isSharing = true
                return
            }
        } catch {
            // Propagate errors to caller for logging; state remains unchanged
            throw error
        }
        
        // Last resort: fetch the CKShare record directly from CloudKit using the stored recordName
        if let recordName = UserDefaults.standard.string(forKey: "shareRecordName") {
            let recordID = CKRecord.ID(recordName: recordName)
            let record = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<CKRecord, Error>) in
                container.privateCloudDatabase.fetch(withRecordID: recordID) { record, error in
                    if let error { cont.resume(throwing: error) }
                    else if let record { cont.resume(returning: record) }
                    else { cont.resume(throwing: NSError(domain: "Spichr", code: -3, userInfo: nil)) }
                }
            }
            if let ckShare = record as? CKShare {
                self.share = ckShare
                self.participants = ckShare.participants.filter { $0 != ckShare.owner }
                self.isShared = true
                self.isSharing = true
                logger.info("Recovered CKShare from CloudKit using stored recordName")
                return
            }
        }

        // No share found; clear participants
        self.participants = []
    }
    
    // MARK: - Helper Methods
    
    func configureCloudKit() {
        Task {
            do {
                let status = try await container.accountStatus()
                if status == .available {
                    logger.info("iCloud account available")
                } else {
                    logger.warning("iCloud account not available: \(status.rawValue)")
                }
            } catch {
                logger.error("Failed to check iCloud status: \(error)")
            }
        }
    }
}

