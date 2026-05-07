//
//  WelcomeView.swift
//  Spichr
//

import SwiftUI

struct WelcomeView: View {

    @Binding var isPresented: Bool
    @State private var notificationsRequested = false

    private let features: [(icon: String, color: Color, title: LocalizedStringKey, desc: LocalizedStringKey)] = [
        ("calendar.badge.exclamationmark", .orange,  "welcome_feature_track_title",  "welcome_feature_track_desc"),
        ("bell.badge.fill",               .blue,    "welcome_feature_notify_title", "welcome_feature_notify_desc"),
        ("person.2.fill",                 .green,   "welcome_feature_share_title",  "welcome_feature_share_desc"),
        ("barcode.viewfinder",            .purple,  "welcome_feature_scan_title",   "welcome_feature_scan_desc"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: - Logo + Headline
            VStack(spacing: 16) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.tint)
                    .symbolEffect(.bounce, options: .repeating.speed(0.3))

                VStack(spacing: 6) {
                    Text("welcome_title")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("welcome_subtitle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 48)

            // MARK: - Feature List
            VStack(spacing: 20) {
                ForEach(features.indices, id: \.self) { i in
                    FeatureRow(icon: features[i].icon, color: features[i].color,
                               title: features[i].title, description: features[i].desc)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // MARK: - Actions
            VStack(spacing: 12) {
                if !notificationsRequested {
                    Button {
                        requestNotifications()
                    } label: {
                        Label("welcome_enable_notifications", systemImage: "bell.badge.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.tint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button {
                    isPresented = false
                } label: {
                    Text(notificationsRequested ? "welcome_get_started" : "welcome_maybe_later")
                        .font(notificationsRequested ? .headline : .subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, notificationsRequested ? 14 : 10)
                        .background(notificationsRequested ? Color.accentColor : Color.clear)
                        .foregroundStyle(notificationsRequested ? Color.white : Color.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .interactiveDismissDisabled()
    }

    private func requestNotifications() {
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            await MainActor.run {
                notificationsRequested = true
                if granted {
                    NotificationService.shared.registerNotificationCategories()
                }
            }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView(isPresented: .constant(true))
}
