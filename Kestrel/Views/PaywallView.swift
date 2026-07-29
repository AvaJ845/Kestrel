import SwiftUI
import StoreKit

/// Kestrel Pro paywall. The pitch is honest: Pro adds breadth and a steadier
/// baseline — the same science, more of it. It never claims better foresight.
struct PaywallView: View {
    @Bindable var entitlements: EntitlementStore
    var reason: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    if let reason {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    benefits
                    plans
                    honesty
                    legal
                }
                .padding()
            }
            .navigationTitle("Kestrel Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore") { Task { await entitlements.restore() } }
                }
            }
            .onChange(of: entitlements.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "bird.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.tint)
            Text("More of the honest signal")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("infinity", "Unlimited stations & alerts",
                    "Watch as many cities as you like and set a spike alert on each — the free tier stops at \(FreeTierLimits.maxStations) stations and \(FreeTierLimits.maxAlertsFree) alert.")
            benefit("chart.line.uptrend.xyaxis", "Choose your baseline",
                    "Free is a \(FreeTierLimits.baselineDaysFree)-day window. Pro lets you dial it up to 14 or \(FreeTierLimits.baselineDaysPro) days — steadier, less jumpy anomalies.")
            benefit("square.stack.3d.up", "Multi-model agreement",
                    "See how much independent weather models concur on each station — a confidence signal you can act on with clear eyes.")
            benefit("lock.shield", "Same honesty, always",
                    "Pro adds breadth, never certainty. Kestrel still measures what's unusual now — never what happens next.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var plans: some View {
        if entitlements.products.isEmpty {
            ProgressView().padding()
        } else {
            VStack(spacing: 12) {
                if let yearly = entitlements.yearlyProduct {
                    planButton(
                        yearly,
                        subtitle: trialSubtitle(for: yearly),
                        highlighted: true
                    )
                }
                if let monthly = entitlements.monthlyProduct {
                    planButton(monthly, subtitle: "\(monthly.displayPrice)/month", highlighted: false)
                }
            }
        }
    }

    private func trialSubtitle(for yearly: Product) -> String {
        var s = "7-day free trial, then \(yearly.displayPrice)/year"
        if let pct = entitlements.yearlySavingsPercent { s += " · save \(pct)%" }
        return s
    }

    private func planButton(_ product: Product, subtitle: String, highlighted: Bool) -> some View {
        Button {
            Task { await entitlements.purchase(product) }
        } label: {
            VStack(spacing: 3) {
                HStack {
                    Text(product.displayName).font(.headline)
                    if highlighted {
                        Text("BEST VALUE")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(.tint, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                Text(subtitle).font(.subheadline).foregroundStyle(highlighted ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(highlighted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.secondarySystemBackground)),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(highlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
    }

    private var honesty: some View {
        Text("Kestrel is a research and education tool. It is not a forecast, and not financial, trading, or betting advice. Subscriptions renew automatically until cancelled in Settings.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var legal: some View {
        HStack(spacing: 18) {
            Link("Privacy", destination: AppLegal.privacyURL)
            Link("Terms", destination: AppLegal.termsURL)
        }
        .font(.footnote)
    }
}
