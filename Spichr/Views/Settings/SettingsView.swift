//
//  SettingsView.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationStack {
            Form {
                // Statistics Section
                Section("statistics") {
                    HStack {
                        Text("total_items")
                        Spacer()
                        Text("\(viewModel.totalItems)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("stock_items")
                        Spacer()
                        Text("\(viewModel.stockItems)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("shopping_items")
                        Spacer()
                        Text("\(viewModel.shoppingItems)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("expiring_soon")
                        Spacer()
                        Text("\(viewModel.expiringItemsCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Notifications Section
                Section("notifications") {
                    Toggle("enable_notifications", isOn: $viewModel.notificationsEnabled)
                        .onChange(of: viewModel.notificationsEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    await viewModel.requestNotificationAuthorization()
                                }
                            }
                        }
                    
                    if viewModel.notificationsEnabled {
                        Toggle("daily_summary", isOn: $viewModel.dailySummaryEnabled)
                        
                        if viewModel.dailySummaryEnabled {
                            DatePicker("summary_time", selection: $viewModel.dailySummaryTime, displayedComponents: .hourAndMinute)
                        }
                        
                        Toggle("expiring_30_days", isOn: $viewModel.expiring30DaysEnabled)
                        Toggle("expiring_7_days", isOn: $viewModel.expiring7DaysEnabled)
                        Toggle("expiring_tomorrow", isOn: $viewModel.expiring1DayEnabled)
                        Toggle("expiring_today", isOn: $viewModel.expiringTodayEnabled)
                        Toggle("opened_items", isOn: $viewModel.openedItemsEnabled)
                        
                        Button("open_settings") {
                            viewModel.openNotificationSettings()
                        }
                    }
                }
                
                // iCloud Section
                Section("icloud") {
                    HStack {
                        Text("account_status")
                        Spacer()
                        Text(viewModel.iCloudAccountStatus)
                            .foregroundStyle(.secondary)
                    }
                    
                    Toggle("sync_enabled", isOn: $viewModel.iCloudSyncEnabled)
                        .disabled(true)
                }
                
                // Data Management Section
                Section("data_management") {
                    Button("export_data") {
                        Task {
                            do {
                                exportURL = try await viewModel.exportData()
                                showingShareSheet = true
                            } catch {
                                print("Export failed: \(error)")
                            }
                        }
                    }
                    
                    Button("delete_all_data", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
                
                // Household Sharing Section
                Section {
                    NavigationLink {
                        SimpleHouseholdView()
                    } label: {
                        HStack {
                            Image(systemName: "person.2.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("manage_household")
                                    .font(.headline)
                                
                                Text("share_with_family")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("share_household")
                } footer: {
                    Text("household_sharing_description")
                }
                
                // About Section
                Section("about") {
                    HStack {
                        Text("version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("build")
                        Spacer()
                        Text(viewModel.buildNumber)
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://sites.google.com/view/spichrprivacypolicy/startseite")!) {
                        HStack {
                            Label {
                                Text("privacy_policy")
                            } icon: {
                                Image(systemName: "hand.raised.fill")
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "https://sites.google.com/view/spichr/startseite")!) {
                        HStack {
                            Label {
                                Text("help_support")
                            } icon: {
                                Image(systemName: "questionmark.circle.fill")
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "mailto:spichr.contact@gmail.com")!) {
                        HStack {
                            Label {
                                Text("contact")
                            } icon: {
                                Image(systemName: "envelope.fill")
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/Sebastian-Kerski/Spichr")!) {
                        HStack {
                            Label {
                                Text("github")
                            } icon: {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                }
                
                // Support Developer Section
                Section {
                    NavigationLink {
                        TipJarView()
                    } label: {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                                .foregroundStyle(.red)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("support_spichr")
                                    .font(.headline)
                                
                                Text("buy_coffee")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("support_developer")
                } footer: {
                    Text("spichr_free_message")
                }
            }
            .navigationTitle("settings")
            .alert("delete_confirmation", isPresented: $showingDeleteAlert) {
                Button("cancel", role: .cancel) { }
                Button("delete", role: .destructive) {
                    Task {
                        try? await viewModel.deleteAllData()
                    }
                }
            } message: {
                Text("delete_warning")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ActivityView(activityItems: [url])
                }
            }
            .onAppear {
                viewModel.loadStatistics()
                viewModel.checkiCloudStatus()
            }
        }
    }
}

// Activity View Controller for sharing
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
}
