import SwiftUI

/// A short, honest welcome — three cards, then straight into the radar.
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    private struct Slide: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
        let tint: Color
    }

    private let slides: [Slide] = [
        .init(symbol: "dot.radiowaves.left.and.right",
              title: "An anomaly radar",
              body: "Kestrel watches cities and shows where the weather is breaking its own rhythm — right now.",
              tint: Color(red: 0.93, green: 0.48, blue: 0.22)),
        .init(symbol: "chart.line.uptrend.xyaxis",
              title: "Unusual for this hour",
              body: "Each city is scored against its own recent same-hour history. Hot isn't unusual in Phoenix — but a cool afternoon in Denver is.",
              tint: Color(red: 0.90, green: 0.62, blue: 0.10)),
        .init(symbol: "checkmark.seal",
              title: "Honest by design",
              body: "It's research and education — never a forecast, and not financial, trading, or betting advice. Everything runs on your device. No account, no tracking.",
              tint: .green),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { idx, slide in
                    slideView(slide).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < slides.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onDone()
                }
            } label: {
                Text(page < slides.count - 1 ? "Continue" : "Start watching")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(slide.tint.opacity(0.15)).frame(width: 132, height: 132)
                Image(systemName: slide.symbol)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(slide.tint)
            }
            Text(slide.title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(slide.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}
