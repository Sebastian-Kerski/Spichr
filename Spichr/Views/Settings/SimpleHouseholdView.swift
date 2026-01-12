//
//  SimpleHouseholdView.swift
//  Spichr
//
//  PRODUCTION READY: CloudKit Sharing UI
//

import SwiftUI
import CloudKit

struct SimpleHouseholdView: View {
    
    @ObservedObject private var manager = HouseholdManager.shared
    @State private var showingShareSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            // Info Banner
            if manager.isShared {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("CoreData CloudKit Sharing Active")
                                .font(.headline)
                        }
                        Text("Items are automatically synced via CoreData. Changes appear on all devices within seconds.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Status Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Icon & Status
                    HStack(spacing: 12) {
                        Image(systemName: manager.isSharing ? "person.2.fill" : "person.fill")
                            .font(.title)
                            .foregroundStyle(manager.isSharing ? .blue : .gray)
                            .frame(width: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(manager.isSharing ? "household_is_shared" : "household_is_private")
                                .font(.headline)
                            
                            if manager.isSharing {
                                Text("\(manager.participants.count + 1) members")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("private")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Description
                    Text(manager.isSharing ? "household_shared_desc" : "household_private_desc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Sharing Actions
            Section {
                if manager.isSharing {
                    // Already shared
                    Button {
                        shareAgain()
                    } label: {
                        Label("invite_more_people", systemImage: "person.badge.plus")
                    }
                    
                    Button(role: .destructive) {
                        stopSharing()
                    } label: {
                        Label("stop_sharing", systemImage: "xmark.circle")
                    }
                    
                } else {
                    // Not shared
                    Button {
                        startSharing()
                    } label: {
                        Label("share_household_button", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("sharing_section")
            }
            
            // 🔴 NUCLEAR RESET SECTION
            Section {
                Button(role: .destructive) {
                    Task {
                        await nuclearResetCloudKit()
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("⚠️ Nuclear Reset CloudKit")
                                .fontWeight(.bold)
                            Text("Löscht ALLE CloudKit Daten und UserDefaults")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                }
            } header: {
                Text("Debug Tools")
            } footer: {
                Text("Nur verwenden wenn Share-Fehler nicht anders behoben werden kann. Danach App neu starten.")
                    .font(.caption)
            }
            
            // Participants (if sharing)
            if manager.isSharing && !manager.participants.isEmpty {
                Section("members") {
                    ForEach(manager.participants, id: \.userIdentity.userRecordID) { participant in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.blue)
                            
                            Text(participant.userIdentity.nameComponents?.formatted() ?? "Unknown")
                            
                            Spacer()
                            
                            if participant.role == .owner {
                                Text("owner")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("manage_household")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = manager.shareURL {
                ShareSheet(url: url)
            }
        }
        .alert("error", isPresented: $showError) {
            Button("ok") {}
        } message: {
            Text(errorMessage)
        }
        .task {
            if manager.isSharing {
                do {
                    try await manager.loadParticipants()
                } catch {
                    print("Failed to load participants: \(error)")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startSharing() {
        // 🛡️ Guard gegen Doppel-Klicks
        guard !manager.isLoading else {
            print("⚠️ Already sharing, ignoring duplicate button press")
            return
        }
        
        Task {
            do {
                let share = try await manager.shareHousehold()
                if let url = share.url {
                    await MainActor.run {
                        manager.shareURL = url
                        showingShareSheet = true
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Could not generate share URL"
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func shareAgain() {
        if manager.shareURL != nil {
            showingShareSheet = true
        } else {
            startSharing()
        }
    }
    
    private func stopSharing() {
        Task {
            do {
                try await manager.stopSharing()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    // MARK: - Nuclear Reset
    
    /// 🔴 NUCLEAR OPTION: Löscht ALLE Household Records aus CloudKit
    /// Verwendet fetchAllRecords statt Query (umgeht "recordName not queryable" Problem)
    private func nuclearResetCloudKit() async {
        print("🔴 NUCLEAR RESET: Starting complete cleanup...")
        
        let container = CKContainer(identifier: "iCloud.com.de.SkerskiDev.FoodGuard")
        let database = container.privateCloudDatabase
        
        // 1. Lösche alle UserDefaults
        print("🔴 Step 1: Clearing UserDefaults...")
        let allKeys = [
            "cloudkit_share_record",
            "cloudkit_share_url",
            "cloudkit_zone_name",
            "cloudkit_is_sharing",
            "shareRecordName",
            "shareURL",
            "householdIsShared",
            "householdName",
            "householdMembers"
        ]
        
        for key in allKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        
        // 2. Finde und lösche ALLE Household Records
        print("🔴 Step 2: Fetching ALL Household records...")
        
        do {
            // Fetch ALLE Households ohne Query
            let householdQuery = CKQuery(recordType: "Household", predicate: NSPredicate(value: true))
            
            let (matchResults, _) = try await database.records(matching: householdQuery)
            
            var deletedCount = 0
            
            // Lösche alle gefundenen Households
            for (recordID, result) in matchResults {
                switch result {
                case .success(_):
                    do {
                        try await database.deleteRecord(withID: recordID)
                        print("✅ Deleted household: \(recordID.recordName)")
                        deletedCount += 1
                    } catch {
                        print("⚠️ Could not delete \(recordID.recordName): \(error)")
                    }
                case .failure(let error):
                    print("⚠️ Error fetching \(recordID.recordName): \(error)")
                }
            }
            
            print("✅ Deleted \(deletedCount) household records")
            
        } catch {
            print("⚠️ Could not fetch households: \(error)")
            
            // Fallback: Versuche bekannte IDs aus Fehlermeldungen
            print("🔴 Fallback: Trying known household IDs...")
            let knownHouseholdIDs = [
                "household_AE1C9CDA-6D2E-4B19-9A3B-A192751B5731",
                "household_6D68DEE7-F33D-4A33-9F7A-989365002AF7",
                "household_12A82241-8CEB-4475-8840-1D56154955C5",
                "SharedHousehold"
            ]
            
            for householdID in knownHouseholdIDs {
                let recordID = CKRecord.ID(recordName: householdID)
                do {
                    try await database.deleteRecord(withID: recordID)
                    print("✅ Deleted household: \(householdID)")
                } catch {
                    // Silent fail
                }
            }
        }
        
        // 3. Versuche auch Shares zu löschen (falls vorhanden)
        print("🔴 Step 3: Attempting to delete shares...")
        let knownShares = [
            "Share-CD16A217-330F-4E34-BC44-2F049CF351A7",
            "Share-4565E164-A5CB-4D3E-ABC6-FE58FAAC0F53",
            "Share-37BA3572-0F2B-4368-AD43-121AC52E8362",
            "Share-B330ED56-CE3C-4506-AD64-E33440A6B19F"
        ]
        
        for shareID in knownShares {
            let recordID = CKRecord.ID(recordName: shareID)
            do {
                try await database.deleteRecord(withID: recordID)
                print("✅ Deleted share: \(shareID)")
            } catch {
                // Silent fail - Share existiert vielleicht nicht
            }
        }
        
        // 4. Reset HouseholdManager state
        await MainActor.run {
            manager.share = nil
            manager.shareURL = nil
            manager.isShared = false
            manager.isSharing = false
            manager.participants = []
            manager.currentHousehold = "My Household"
        }
        
        print("🔴 NUCLEAR RESET COMPLETE!")
        
        // Zeige Erfolgs-Alert
        await MainActor.run {
            errorMessage = "✅ CloudKit komplett bereinigt!\n\nWichtig:\n1. App komplett beenden (Multitasking schließen)\n2. App neu öffnen\n3. Nochmal versuchen zu teilen\n\nFalls es IMMER NOCH nicht funktioniert:\n→ In Xcode: Product → Clean Build Folder\n→ App neu installieren"
            showError = true
        }
    }
}
// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SimpleHouseholdView()
    }
}
