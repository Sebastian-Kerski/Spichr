//
//  ContentView.swift
//  Spichr
//
//  Created by Sebastian Skerski
//

import SwiftUI
import CoreData

struct ContentView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var persistenceController: PersistenceController
    
    var body: some View {
        TabView {
            StockListView()
                .tabItem {
                    Label(LocalizedStringKey("tab_stock"), systemImage: "archivebox.fill")
                }
            
            ShoppingListView()
                .tabItem {
                    Label(LocalizedStringKey("tab_shopping"), systemImage: "cart.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label(LocalizedStringKey("tab_settings"), systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environmentObject(PersistenceController.preview)
}
