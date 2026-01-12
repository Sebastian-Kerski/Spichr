//
//  SpichrApp.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import os

@main
struct SpichrApp: App {
    
    // MARK: - Persistence
    
    @StateObject private var persistenceController = PersistenceController.shared
    
    // MARK: - Services
    
    @StateObject private var notificationService = NotificationService.shared
    private let logger = Logger(subsystem: "com.de.SkerskiDev.Spichr", category: "Startup")
    
    // MARK: - Initialization
    
    init() {
        // Register notification categories
        NotificationService.shared.registerNotificationCategories()
        logger.info("SpichrApp init: registered notification categories")
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if persistenceController.isReady {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.viewContext)
                        .environmentObject(persistenceController)
                        .environmentObject(notificationService)
                        .task {
                            // Defer potentially heavy work until after first frame
                            notificationService.checkAuthorizationStatus()
                            if notificationService.isAuthorized {
                                notificationService.scheduleDailySummary()
                            }
                            notificationService.updateBadgeCount()
                            
                            // 🔧 Automatischer CloudKit Cleanup beim App-Start
                            // Behebt "orphaned share" Fehler
                            await performCloudKitCleanupIfNeeded()
                        }
                        .onAppear {
                            // Update badge count
                            notificationService.updateBadgeCount()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            // Update badge when app becomes active
                            notificationService.updateBadgeCount()
                            notificationService.checkAuthorizationStatus()
                        }
                        .onOpenURL { url in
                            // Handle CloudKit share URLs
                            handleIncomingURL(url)
                        }
                } else {
                    Color(.systemBackground).ignoresSafeArea()
                }
                
                if !persistenceController.isReady {
                    ZStack {
                        Color(.systemBackground).opacity(0.95).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView(LocalizedStringKey("loading"))
                            Text(LocalizedStringKey("please_wait"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .task {
                // Ensure Core Data stores start loading after first frame, with timeout fallback
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await persistenceController.start()
                    }
                    group.addTask {
                        try? await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5s timeout
                        await MainActor.run {
                            if !persistenceController.isReady {
                                persistenceController.fallbackToInMemoryIfNeeded()
                            }
                        }
                    }
                    await group.waitForAll()
                }
            }
        }
    }
    
    // MARK: - URL Handling
    
    /// Handles incoming URLs (e.g., CloudKit share invitations)
    private func handleIncomingURL(_ url: URL) {
        logger.info("🔵 Received URL: \(url.absoluteString)")
        
        // Check if this is a CloudKit share URL
        guard url.host == "www.icloud.com" && url.pathComponents.contains("share") else {
            logger.info("⚠️ Not a CloudKit share URL, ignoring")
            return
        }
        
        logger.info("✅ Detected CloudKit share URL!")
        
        // Accept the share
        Task {
            do {
                let householdManager = HouseholdManager.shared
                try await householdManager.acceptShare(url: url)
                logger.info("✅ Share accepted successfully via URL handler!")
            } catch {
                logger.error("❌ Failed to accept share: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - CloudKit Cleanup
    
    /// Führt CloudKit Cleanup beim ersten Start nach Installation aus
    private func performCloudKitCleanupIfNeeded() async {
        let hasRunCleanupKey = "cloudkit_cleanup_has_run_v2" // v2 = simplified version
        
        // Nur beim ersten Start ausführen
        guard !UserDefaults.standard.bool(forKey: hasRunCleanupKey) else {
            logger.info("CloudKit cleanup already performed, skipping")
            return
        }
        
        logger.info("🔧 Performing initial CloudKit cleanup...")
        
        // Bereinige nur UserDefaults (keine komplexen CloudKit Queries)
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
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        
        // Merken dass Cleanup durchgeführt wurde
        UserDefaults.standard.set(true, forKey: hasRunCleanupKey)
        logger.info("✅ CloudKit cleanup completed successfully")
    }
}

