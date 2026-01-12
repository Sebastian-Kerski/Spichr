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
    
    /// Whether the current user is the owner of the share
    var isOwner: Bool {
        isSharing
    }
    
    // MARK: - Singleton
    
    static let shared = HouseholdManager()
    
    let container = CKContainer(identifier: "iCloud.com.de.SkerskiDev.FoodGuard")
    var share: CKShare?
    
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
            print("⚠️ Share operation already in progress")
            throw NSError(domain: "Spichr", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Share operation already in progress"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print("🔵 Starting CoreData CloudKit Sharing...")
        
        // Check if we already have a share
        if let existingShare = self.share, let existingURL = existingShare.url {
            print("✅ Share already exists: \(existingURL.absoluteString)")
            return existingShare
        }
        
        // Get all FoodItems
        let context = PersistenceController.shared.viewContext
        let fetchRequest = FoodItem.fetchRequest()
        let items = try context.fetch(fetchRequest)
        
        print("📦 Found \(items.count) items to share")
        
        guard !items.isEmpty else {
            print("⚠️ No items to share, creating placeholder...")
            // Create a placeholder item
            let placeholder = FoodItem(context: context)
            placeholder.id = UUID()
            placeholder.name = "Shared Household"
            placeholder.isInStock = false
            placeholder.lastModified = Date()
            try context.save()
            
            return try await shareItems([placeholder])
        }
        
        return try await shareItems(items)
    }
    
    @MainActor
    private func shareItems(_ items: [FoodItem]) async throws -> CKShare {
        print("🔵 Sharing \(items.count) items using CoreData...")
        
        // Use PersistenceController's share function
        let (share, _) = try await PersistenceController.shared.shareItems(items)
        
        guard let shareURL = share.url else {
            throw NSError(domain: "Spichr", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Share has no URL"])
        }
        
        print("✅ Share created successfully!")
        print("✅ Share URL: \(shareURL.absoluteString)")
        
        // Update state
        self.share = share
        self.shareURL = shareURL
        self.isShared = true
        self.isSharing = true
        
        // Update participants
        let currentUser = share.owner
        participants = share.participants.filter { $0 != currentUser }
        
        save()
        
        // Notify about sharing status change
        NotificationCenter.default.post(
            name: NSNotification.Name("HouseholdSharingStatusChanged"),
            object: nil
        )
        
        return share
    }
    
    // MARK: - ACCEPT SHARE
    
    /// Accepts a share invitation
    @MainActor
    func acceptShare(url: URL) async throws {
        isLoading = true
        defer { isLoading = false }
        
        print("🔵 Accepting share from URL...")
        
        // Get share metadata
        let metadata = try await container.shareMetadata(for: url)
        print("✅ Share metadata retrieved")
        
        // Accept share
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            
            operation.perShareResultBlock = { metadata, result in
                switch result {
                case .success:
                    print("✅ Share accepted successfully")
                case .failure(let error):
                    print("❌ Failed to accept share: \(error)")
                @unknown default:
                    print("⚠️ Unknown result")
                }
            }
            
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                @unknown default:
                    continuation.resume(throwing: NSError(domain: "Spichr", code: -1,
                                                          userInfo: [NSLocalizedDescriptionKey: "Unknown result"]))
                }
            }
            
            container.add(operation)
        }
        
        // Update state
        isShared = true
        isSharing = false // We're a participant, not owner
        self.shareURL = url
        save()
        
        print("✅ Share accepted and configured")
        
        // CoreData will automatically sync the shared items!
        // No need to manually import
        print("✅ CoreData will automatically sync shared items")
    }
    
    // MARK: - STOP SHARING
    
    /// Stops sharing the household
    @MainActor
    func stopSharing() async throws {
        guard isShared else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        print("🔵 Stopping share...")
        
        // Get all shared items
        let context = PersistenceController.shared.viewContext
        let fetchRequest = FoodItem.fetchRequest()
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
        
        print("✅ Sharing stopped")
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
        
        // Try to resolve a share from any existing FoodItem in the store
        let context = PersistenceController.shared.viewContext
        let fetchRequest = FoodItem.fetchRequest()
        
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
        
        // No share found; clear participants
        self.participants = []
    }
    
    // MARK: - Helper Methods
    
    func configureCloudKit() {
        Task {
            do {
                let status = try await container.accountStatus()
                if status == .available {
                    print("✅ iCloud account available")
                } else {
                    print("⚠️ iCloud account not available: \(status.rawValue)")
                }
            } catch {
                print("❌ Failed to check iCloud status: \(error)")
            }
        }
    }
}

