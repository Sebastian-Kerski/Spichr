//
//  SpichrApp.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import CloudKit
import AppIntents
import os

// MARK: - AppDelegate

/// Injects SceneDelegate so iOS can deliver CloudKit share invitations
/// via windowScene(_:userDidAcceptCloudKitShareWith:).
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// MARK: - SceneDelegate

/// ✅ FIX: Receives CloudKit share invitations when a user with a different Apple ID
/// taps a share link. Without this, the share URL is silently dropped.
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            await HouseholdManager.shared.acceptCloudKitShare(metadata: cloudKitShareMetadata)
        }
    }
}

// MARK: - App

@main
struct SpichrApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Persistence

    @StateObject private var persistenceController = PersistenceController.shared

    // MARK: - Services

    @StateObject private var notificationService = NotificationService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let proManager = ProManager.shared
    private let logger = Logger(subsystem: "com.de.SkerskiDev.Spichr", category: "Startup")
    
    // MARK: - Initialization
    
    init() {
        NotificationService.shared.registerNotificationCategories()
        SpichrAppShortcuts.updateAppShortcutParameters()
        logger.info("SpichrApp init: registered notification categories + Siri shortcuts")
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
                        .environment(networkMonitor)
                        .environment(proManager)
                        .task {
                            notificationService.checkAuthorizationStatus()
                            if notificationService.isAuthorized {
                                notificationService.scheduleDailySummary()
                            }
                            notificationService.updateBadgeCount()
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
                        persistenceController.migrateOldItemsToDefaultHousehold()
                        persistenceController.removeOrphanedSharedItems()
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
    
}

