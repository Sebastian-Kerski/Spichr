//
//  ActivityLogView.swift
//  Spichr
//

import SwiftUI
import CoreData
import CloudKit

// MARK: - Activity Entry Model

struct ActivityEntry: Identifiable {
    let id = UUID()
    let itemName: String
    let action: Action
    let date: Date
    let userDisplayName: String

    enum Action: String {
        case added    = "activity_added"
        case modified = "activity_modified"
        case deleted  = "activity_deleted"

        var icon: String {
            switch self {
            case .added:    return "plus.circle.fill"
            case .modified: return "pencil.circle.fill"
            case .deleted:  return "minus.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .added:    return .green
            case .modified: return .blue
            case .deleted:  return .red
            }
        }
    }
}

// MARK: - ViewModel

@Observable
final class ActivityLogViewModel {

    var entries: [ActivityEntry] = []
    var isLoading = false
    var selectedUser: String? = nil
    var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    var endDate: Date = Date()

    private let container: NSPersistentCloudKitContainer
    private var userNameCache: [String: String] = [:]

    init(container: NSPersistentCloudKitContainer = PersistenceController.shared.container) {
        self.container = container
    }

    var filteredEntries: [ActivityEntry] {
        entries.filter { entry in
            let inDateRange = entry.date >= startDate && entry.date <= endDate
            if let user = selectedUser {
                return inDateRange && entry.userDisplayName == user
            }
            return inDateRange
        }
    }

    var uniqueUsers: [String] {
        Array(Set(entries.map { $0.userDisplayName })).sorted()
    }

    func load() async {
        await MainActor.run { isLoading = true }
        let loaded = await fetchActivityEntries()
        await MainActor.run {
            entries = loaded
            isLoading = false
        }
    }

    private func fetchActivityEntries() async -> [ActivityEntry] {
        let context = container.viewContext
        let request = FoodItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.lastModified, ascending: false)]
        request.fetchLimit = 200

        guard let items = try? context.fetch(request) else { return [] }

        var result: [ActivityEntry] = []
        let ckContainer = CKContainer(identifier: AppConstants.CloudKit.containerIdentifier)

        for item in items {
            guard let lastMod = item.lastModified else { continue }

            // Try to get CKRecord metadata
            var userName = NSLocalizedString("activity_me", comment: "Me")
            if let recordID = try? await resolveUserRecordID(for: item, in: ckContainer) {
                userName = await resolveUserName(recordID: recordID, container: ckContainer)
            }

            let isNew = abs(lastMod.timeIntervalSince(item.lastModified ?? lastMod)) < 1
            result.append(ActivityEntry(
                itemName: item.unwrappedName,
                action: isNew ? .added : .modified,
                date: lastMod,
                userDisplayName: userName
            ))
        }

        return result.sorted { $0.date > $1.date }
    }

    private func resolveUserRecordID(for item: FoodItem, in ckContainer: CKContainer) async throws -> CKRecord.ID? {
        // CloudKit metadata is only accessible via the NSPersistentCloudKitContainer event API
        // or by fetching the CKRecord directly. We use the shareReference (CKRecord name) if set.
        guard let recordName = item.shareReference else { return nil }
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try? await ckContainer.privateCloudDatabase.record(for: recordID)
        return record?.creatorUserRecordID
    }

    private func resolveUserName(recordID: CKRecord.ID, container: CKContainer) async -> String {
        let key = recordID.recordName
        if let cached = userNameCache[key] { return cached }

        do {
            let identity = try await container.userIdentity(forUserRecordID: recordID)
            let name = [identity?.nameComponents?.givenName, identity?.nameComponents?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let display = name.isEmpty ? NSLocalizedString("activity_unknown_user", comment: "") : name
            userNameCache[key] = display
            return display
        } catch {
            return NSLocalizedString("activity_unknown_user", comment: "")
        }
    }
}

// MARK: - View

struct ActivityLogView: View {

    @State private var viewModel = ActivityLogViewModel()
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredEntries.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("activity_empty_title"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(LocalizedStringKey("activity_empty_desc"))
                    )
                } else {
                    List(viewModel.filteredEntries) { entry in
                        ActivityEntryRow(entry: entry)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(LocalizedStringKey("activity_log_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: viewModel.selectedUser != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                ActivityFilterView(viewModel: viewModel)
            }
            .task { await viewModel.load() }
        }
    }
}

// MARK: - Entry Row

private struct ActivityEntryRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.action.icon)
                .font(.title2)
                .foregroundStyle(entry.action.color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.itemName)
                        .font(.headline)
                    Spacer()
                    Text(entry.date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(entry.action.rawValue))
                        .font(.caption)
                        .foregroundStyle(entry.action.color)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(entry.userDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Filter Sheet

private struct ActivityFilterView: View {
    @Bindable var viewModel: ActivityLogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("activity_filter_date")) {
                    DatePicker(LocalizedStringKey("activity_filter_from"), selection: $viewModel.startDate, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("activity_filter_to"), selection: $viewModel.endDate, displayedComponents: .date)
                }

                if !viewModel.uniqueUsers.isEmpty {
                    Section(LocalizedStringKey("activity_filter_user")) {
                        Button(LocalizedStringKey("activity_filter_all_users")) {
                            viewModel.selectedUser = nil
                        }
                        .foregroundStyle(viewModel.selectedUser == nil ? .primary : .secondary)

                        ForEach(viewModel.uniqueUsers, id: \.self) { user in
                            Button(user) { viewModel.selectedUser = user }
                                .foregroundStyle(viewModel.selectedUser == user ? .primary : .secondary)
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("activity_filter_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("action_done")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ActivityLogView()
}
