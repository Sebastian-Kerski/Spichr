//
//  SimpleHouseholdView.swift
//  Spichr
//

import SwiftUI
import os
import CloudKit

struct SimpleHouseholdView: View {
    private let logger = Logger(subsystem: "com.de.SkerskiDev.Spichr", category: "Household")

    @ObservedObject private var manager = HouseholdManager.shared
    @State private var showingCloudSharing = false
    @State private var cloudShare: CKShare?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var iCloudAvailable: Bool = true
    @State private var isPreparingShare = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // iCloud availability warning
            if !iCloudAvailable {
                Section {
                    Label {
                        Text(LocalizedStringKey("icloud_not_signed_in"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "exclamationmark.icloud.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Active sharing info banner
            if manager.isShared {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(LocalizedStringKey("household_is_shared"))
                                .font(.headline)
                        }
                        Text(LocalizedStringKey("household_shared_desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Status Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: manager.isSharing ? "person.2.fill" : "person.fill")
                            .font(.title)
                            .foregroundStyle(manager.isSharing ? .blue : .gray)
                            .frame(width: 50)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(manager.isSharing ? "household_is_shared" : "household_is_private"))
                                .font(.headline)

                            if manager.isSharing {
                                Text(String(format: NSLocalizedString("household_member_count", comment: ""), manager.participants.count + 1))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(LocalizedStringKey("household_is_private"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Text(LocalizedStringKey(manager.isSharing ? "household_shared_desc" : "household_private_desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Sharing Actions
            Section {
                if manager.isSharing {
                    Button {
                        shareAgain()
                    } label: {
                        Label(LocalizedStringKey("invite_more_people"), systemImage: "person.badge.plus")
                    }

                    Button(role: .destructive) {
                        stopSharing()
                    } label: {
                        Label(LocalizedStringKey("stop_sharing"), systemImage: "xmark.circle")
                    }
                } else {
                    if isPreparingShare {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 4)
                            Text(LocalizedStringKey("icloud_connecting"))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            startSharing()
                        } label: {
                            Label(LocalizedStringKey("share_household_button"), systemImage: "square.and.arrow.up")
                        }
                        .disabled(!iCloudAvailable)
                    }
                }
            } header: {
                Text(LocalizedStringKey("sharing_section"))
            }

            // Participants
            if manager.isSharing && !manager.participants.isEmpty {
                Section(LocalizedStringKey("members")) {
                    ForEach(manager.participants, id: \.userIdentity.userRecordID) { participant in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.blue)
                            Text(participant.userIdentity.nameComponents?.formatted() ?? NSLocalizedString("unknown", comment: ""))
                            Spacer()
                            if participant.role == .owner {
                                Text(LocalizedStringKey("owner"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

#if DEBUG
            Section {
                Button(role: .destructive) {
                    Task { await nuclearResetCloudKit() }
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Nuclear Reset CloudKit")
                                .fontWeight(.bold)
                            Text("Deletes ALL CloudKit data and UserDefaults")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                }
            } header: {
                Text("Debug")
            } footer: {
                Text("Only use this if sharing errors cannot be resolved otherwise. Restart the app afterwards.")
                    .font(.caption)
            }
#endif
        }
        .navigationTitle(LocalizedStringKey("manage_household"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCloudSharing) {
            if let share = cloudShare {
                CloudSharingSheet(
                    share: share,
                    container: manager.container,
                    isPresented: $showingCloudSharing
                )
            }
        }
        .alert(LocalizedStringKey("error"), isPresented: $showError) {
            Button(LocalizedStringKey("ok")) {}
        } message: {
            Text(errorMessage)
        }
        .alert(LocalizedStringKey("error"), isPresented: Binding(
            get: { manager.sharingError != nil },
            set: { if !$0 { manager.sharingError = nil } }
        )) {
            Button(LocalizedStringKey("ok")) { manager.sharingError = nil }
        } message: {
            Text(manager.sharingError ?? "")
        }
        .task {
            let status = try? await CKContainer.default().accountStatus()
            iCloudAvailable = (status == .available)
            if manager.isSharing {
                try? await manager.loadParticipants()
            }
        }
    }

    // MARK: - Actions

    private func startSharing() {
        guard !manager.isLoading else { return }

        isPreparingShare = true
        Task {
            do {
                let share = try await manager.shareHousehold()
                await MainActor.run {
                    isPreparingShare = false
                    cloudShare = share
                    showingCloudSharing = true
                }
            } catch {
                await MainActor.run {
                    isPreparingShare = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func shareAgain() {
        if let share = manager.share {
            cloudShare = share
            showingCloudSharing = true
        } else {
            startSharing()
        }
    }

    private func stopSharing() {
        Task {
            do {
                try await manager.stopSharing()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

#if DEBUG
    private func nuclearResetCloudKit() async {
        let container = CKContainer(identifier: AppConstants.CloudKit.containerIdentifier)
        let database = container.privateCloudDatabase

        let keysToRemove = ["cloudkit_share_record", "cloudkit_share_url", "cloudkit_zone_name",
                            "cloudkit_is_sharing", "shareRecordName", "shareURL",
                            "householdIsShared", "householdName", "householdMembers"]
        keysToRemove.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UserDefaults.standard.synchronize()

        do {
            let query = CKQuery(recordType: "Household", predicate: NSPredicate(value: true))
            let (results, _) = try await database.records(matching: query)
            for (recordID, _) in results {
                try? await database.deleteRecord(withID: recordID)
            }
        } catch {
            logger.error("Nuclear reset warning: \(error.localizedDescription)")
        }

        await MainActor.run {
            manager.share = nil
            manager.shareURL = nil
            manager.isShared = false
            manager.isSharing = false
            manager.participants = []
            manager.currentHousehold = "My Household"
            errorMessage = NSLocalizedString("cloudkit_reset_complete", comment: "")
            showError = true
        }
    }
#endif
}

// MARK: - Cloud Sharing Sheet (UICloudSharingController wrapper)

struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let parent: CloudSharingSheet
        private let logger = Logger(subsystem: "com.de.SkerskiDev.Spichr", category: "SimpleHouseholdView")
        init(_ parent: CloudSharingSheet) { self.parent = parent }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            logger.error("CloudSharing error: \(error.localizedDescription)")
            parent.isPresented = false
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            // After the user invites someone, ensure all non-owner participants have readWrite.
            guard let share = csc.share else { parent.isPresented = false; return }
            for participant in share.participants where participant != share.owner {
                participant.permission = CKShare.ParticipantPermission.readWrite
            }
            parent.isPresented = false
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in
                let m = HouseholdManager.shared
                m.share = nil
                m.shareURL = nil
                m.isShared = false
                m.isSharing = false
                m.participants = []
                m.save()
            }
            parent.isPresented = false
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            NSLocalizedString("manage_household", comment: "")
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? { nil }
        func itemType(for csc: UICloudSharingController) -> String? { nil }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SimpleHouseholdView()
    }
}
