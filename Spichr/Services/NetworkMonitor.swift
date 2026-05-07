//
//  NetworkMonitor.swift
//  Spichr
//

import Network
import SwiftUI
import Combine

@Observable
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.de.SkerskiDev.NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

// MARK: - Offline Banner

struct OfflineBanner: View {
    @Environment(NetworkMonitor.self) private var monitor

    var body: some View {
        if !monitor.isConnected {
            HStack(spacing: 6) {
                Image(systemName: "wifi.slash")
                    .font(.caption.bold())
                Text(LocalizedStringKey("offline_banner"))
                    .font(.caption.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.orange, in: Capsule())
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: monitor.isConnected)
        }
    }
}
