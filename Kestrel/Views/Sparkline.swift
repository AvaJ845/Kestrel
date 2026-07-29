import SwiftUI

/// A tiny, chartjunk-free rhythm line (Tufte-style): position + slope carry the
/// signal, the last point is marked, and an optional normal band sits behind.
/// No axes, no labels — it lives at a glance inside a row.
struct Sparkline: View {
    let values: [Double]
    var bandLow: Double?
    var bandHigh: Double?
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            let pts = normalizedPoints(in: geo.size)
            ZStack {
                if let low = bandLow, let high = bandHigh, let range = valueRange, range.span > 0 {
                    let yHigh = y(for: high, in: geo.size, range: range)
                    let yLow = y(for: low, in: geo.size, range: range)
                    Rectangle()
                        .fill(tint.opacity(0.12))
                        .frame(height: max(1, yLow - yHigh))
                        .position(x: geo.size.width / 2, y: (yHigh + yLow) / 2)
                }
                if pts.count > 1 {
                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(tint.opacity(0.85),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                }
                if let last = pts.last {
                    Circle().fill(tint).frame(width: 5, height: 5).position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var valueRange: (min: Double, max: Double, span: Double)? {
        var lo = values.min() ?? 0
        var hi = values.max() ?? 0
        if let bl = bandLow { lo = Swift.min(lo, bl) }
        if let bh = bandHigh { hi = Swift.max(hi, bh) }
        guard hi >= lo else { return nil }
        return (lo, hi, hi - lo)
    }

    private func y(for value: Double, in size: CGSize, range: (min: Double, max: Double, span: Double)) -> CGFloat {
        guard range.span > 0 else { return size.height / 2 }
        let t = (value - range.min) / range.span
        return size.height - CGFloat(t) * size.height
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let range = valueRange else { return [] }
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { idx, v in
            CGPoint(x: CGFloat(idx) * stepX, y: y(for: v, in: size, range: range))
        }
    }
}
