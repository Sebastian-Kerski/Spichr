//
//  ContentView.swift
//  Spichr
//

import SwiftUI
import CoreData

struct ContentView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var persistenceController: PersistenceController
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showWelcome: Bool = !UserDefaults.standard.bool(forKey: "hasSeenWelcome")
    @State private var selectedTab: AppTab = .stock
    @State private var selectedSidebarTab: AppTab? = .stock

    enum AppTab: String, CaseIterable, Identifiable {
        case stock, shopping, insights, settings
        var id: String { rawValue }

        var labelKey: LocalizedStringKey {
            switch self {
            case .stock:    return "tab_stock"
            case .shopping: return "tab_shopping"
            case .insights: return "insights_title"
            case .settings: return "tab_settings"
            }
        }

        var icon: String {
            switch self {
            case .stock:    return "archivebox.fill"
            case .shopping: return "cart.fill"
            case .insights: return "chart.bar.fill"
            case .settings: return "gear"
            }
        }

        @ViewBuilder
        var view: some View {
            switch self {
            case .stock:    StockListView()
            case .shopping: ShoppingListView()
            case .insights: InsightsView()
            case .settings: SettingsView()
            }
        }
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            ipadLayout
        } else {
            phoneLayout
        }
    }

    // MARK: - Phone Layout (TabView)

    private var phoneLayout: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    tab.view
                        .tabItem { Label(tab.labelKey, systemImage: tab.icon) }
                        .tag(tab)
                }
            }
            OfflineBanner()
        }
        .sheet(isPresented: $showWelcome, onDismiss: {
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
        }) {
            WelcomeView(isPresented: $showWelcome)
        }
    }

    // MARK: - iPad Layout (NavigationSplitView)

    private var ipadLayout: some View {
        ZStack(alignment: .top) {
            NavigationSplitView {
                List(AppTab.allCases, selection: $selectedSidebarTab) { tab in
                    Label(tab.labelKey, systemImage: tab.icon).tag(tab)
                }
                .navigationTitle("Spichr")
                .listStyle(.sidebar)
            } detail: {
                (selectedSidebarTab ?? .stock).view
            }
            OfflineBanner()
        }
        .sheet(isPresented: $showWelcome, onDismiss: {
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
        }) {
            WelcomeView(isPresented: $showWelcome)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environmentObject(PersistenceController.preview)
}
