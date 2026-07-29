import SwiftUI

/// About / method / honesty pledge.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "bird")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.tint)
                        Text("Kestrel")
                            .font(.title2.weight(.bold))
                        Text(AppText.oneLiner)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("What Kestrel does") {
                    Text(AppText.methodNote)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("The honesty pledge") {
                    Text(AppText.disclaimerShort)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Text("No account. No tracking. Kestrel fetches only public weather "
                         + "data for the stations you watch, directly from your device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Link("Privacy Policy", destination: AppLegal.privacyURL)
                    Link("Terms of Use", destination: AppLegal.termsURL)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct LoadingState: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning the atmosphere…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyRadarState: View {
    let onChoose: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No stations yet", systemImage: "dot.radiowaves.left.and.right")
        } description: {
            Text("Add a few cities and Kestrel will watch for atmospheric anomalies.")
        } actions: {
            Button("Choose stations", action: onChoose)
                .buttonStyle(.borderedProminent)
        }
    }
}
