//
//  CloudKitDebugView.swift
//  Spichr
//
//  Debug-Tools für CloudKit-Probleme
//

import SwiftUI
import CloudKit

struct CloudKitDebugView: View {
    
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var diagnosticReport = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    private let cleanup = CloudKitCleanupManager()
    
    var body: some View {
        NavigationStack {
            List {
                Section("🔍 Diagnose") {
                    Button {
                        Task { await runDiagnostic() }
                    } label: {
                        Label("Diagnostic Report erstellen", systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(isProcessing)
                    
                    if !diagnosticReport.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Report:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(diagnosticReport)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Section("🔧 Cleanup-Optionen") {
                    Button {
                        Task { await quickFix() }
                    } label: {
                        Label("Quick Fix (Empfohlen)", systemImage: "wrench.and.screwdriver")
                    }
                    .disabled(isProcessing)
                    
                    Button {
                        Task { await fullCleanup() }
                    } label: {
                        Label("Full Cleanup", systemImage: "paintbrush")
                    }
                    .disabled(isProcessing)
                }
                
                Section("⚠️ Erweiterte Optionen") {
                    Button(role: .destructive) {
                        showingAlert = true
                        alertTitle = "Nuclear Reset"
                        alertMessage = "Dies löscht ALLE CloudKit-Daten! Nur für Development verwenden. Fortfahren?"
                    } label: {
                        Label("Nuclear Reset", systemImage: "exclamationmark.triangle.fill")
                    }
                    .disabled(isProcessing)
                }
                
                if !statusMessage.isEmpty {
                    Section("Status") {
                        Text(statusMessage)
                            .font(.caption)
                    }
                }
                
                if isProcessing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Verarbeite...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("CloudKit Debug")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) {
                    Task { await nuclearReset() }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Actions
    
    private func runDiagnostic() async {
        isProcessing = true
        statusMessage = "Erstelle Diagnostic Report..."
        
        diagnosticReport = await cleanup.generateDiagnosticReport()
        
        statusMessage = "Diagnostic Report erstellt ✅"
        isProcessing = false
    }
    
    private func quickFix() async {
        isProcessing = true
        statusMessage = "Führe Quick Fix aus..."
        
        do {
            try await cleanup.quickFixOrphanedShareError()
            statusMessage = "Quick Fix erfolgreich! ✅\nBitte App neu starten."
            
            // Vibration Feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            statusMessage = "Fehler beim Quick Fix: \(error.localizedDescription)"
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isProcessing = false
    }
    
    private func fullCleanup() async {
        isProcessing = true
        statusMessage = "Führe Full Cleanup aus..."
        
        do {
            try await cleanup.performFullCleanup()
            statusMessage = "Full Cleanup erfolgreich! ✅\nBitte App neu starten."
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            statusMessage = "Fehler beim Cleanup: \(error.localizedDescription)"
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isProcessing = false
    }
    
    private func nuclearReset() async {
        isProcessing = true
        statusMessage = "☢️ Führe Nuclear Reset aus..."
        
        do {
            try await cleanup.performNuclearReset()
            statusMessage = "Nuclear Reset abgeschlossen! ☢️\nAlle Daten gelöscht.\nBitte App neu starten."
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        } catch {
            statusMessage = "Fehler beim Nuclear Reset: \(error.localizedDescription)"
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isProcessing = false
    }
}

#Preview {
    CloudKitDebugView()
}
