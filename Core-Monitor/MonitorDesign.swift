import Charts
import SwiftUI

// MARK: - Metric identity

/// One tint per metric, used identically in the sidebar, charts, gauges,
/// and menu bar popovers so a color always means the same thing.
enum MetricTint {
    static let cpu = Color.blue
    static let memory = Color.purple
    static let thermal = Color.orange
    static let cooling = Color.teal
    static let power = Color.green
    static let network = Color.indigo
    static let storage = Color.cyan
    static let rescue = Color.pink
}

/// Severity shared by every reading that has thresholds.
enum ReadingSeverity: Comparable {
    case nominal
    case elevated
    case serious
    case critical

    var color: Color {
        switch self {
        case .nominal: return .green
        case .elevated: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
}

enum ReadingThresholds {
    static func cpuLoad(_ percent: Double) -> ReadingSeverity {
        switch percent {
        case ..<50: return .nominal
        case ..<75: return .elevated
        case ..<90: return .serious
        default: return .critical
        }
    }

    static func memory(_ percent: Double, pressure: MemoryPressureLevel) -> ReadingSeverity {
        switch pressure {
        case .red: return .critical
        case .yellow: return .serious
        case .green: return percent > 85 ? .elevated : .nominal
        }
    }

    static func temperature(_ celsius: Double) -> ReadingSeverity {
        switch celsius {
        case ..<70: return .nominal
        case ..<85: return .elevated
        case ..<95: return .serious
        default: return .critical
        }
    }

    static func disk(_ percent: Double) -> ReadingSeverity {
        switch percent {
        case ..<80: return .nominal
        case ..<90: return .elevated
        case ..<95: return .serious
        default: return .critical
        }
    }

    static func thermalState(_ state: ProcessInfo.ThermalState) -> ReadingSeverity {
        switch state {
        case .nominal: return .nominal
        case .fair: return .elevated
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}

// MARK: - Formatting

enum ReadingFormat {
    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func celsius(_ value: Double?) -> String {
        guard let value else { return "––°" }
        return "\(Int(value.rounded()))°"
    }

    static func celsiusLong(_ value: Double?) -> String {
        guard let value else { return "No reading" }
        return String(format: "%.0f °C", value)
    }

    static func rpm(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic)) + " rpm"
    }

    static func rpmShort(_ value: Int) -> String {
        guard value >= 1000 else { return "\(value)" }
        let thousands = Double(value) / 1000
        let text = String(format: "%.1fk", thousands)
        return text.replacingOccurrences(of: ".0k", with: "k")
    }

    static func watts(_ value: Double?) -> String {
        guard let value else { return "–– W" }
        return String(format: "%.1f W", abs(value))
    }

    static func gigabytes(_ value: Double) -> String {
        guard value > 0 else { return "0 GB" }
        return value >= 100
            ? String(format: "%.0f GB", value)
            : String(format: "%.1f GB", value)
    }

    static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(min(value, UInt64(Int64.max))), countStyle: .memory)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        NetworkThroughputFormatter.compactRate(bytesPerSecond: bytesPerSecond)
    }
}

// MARK: - Typography

extension Font {
    /// Large instrument numeral, e.g. the headline reading on a section page.
    static var readingHero: Font {
        .system(size: 40, weight: .semibold, design: .rounded)
    }

    /// Mid-size numeral used inside cards and popovers.
    static var readingLarge: Font {
        .system(size: 24, weight: .semibold, design: .rounded)
    }

    /// Compact numeral for grid cells and sidebar readouts.
    static var readingSmall: Font {
        .system(size: 13, weight: .medium, design: .rounded)
    }
}

// MARK: - Panel container

/// The one card shape used across the app: rounded, quiet, native.
struct Panel<Content: View>: View {
    var title: String?
    var caption: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, caption: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || caption != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    if let caption {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        )
    }
}

/// A label / value line inside a Panel.
struct ReadingRow: View {
    let label: String
    let value: String
    var note: String?
    var valueColor: Color = .primary

    init(_ label: String, value: String, note: String? = nil, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.note = note
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                Spacer(minLength: 16)
                Text(value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            if let note, note.isEmpty == false {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A thin capacity bar with a label and value, used for breakdowns.
struct CapacityRow: View {
    let label: String
    let value: String
    let fraction: Double
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                Spacer(minLength: 16)
                Text(value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                let clamped = min(max(fraction, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(nsColor: .quaternaryLabelColor))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(proxy.size.width * clamped, clamped > 0 ? 3 : 0))
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Trend charts

/// Area + line chart for a MonitoringTrendSeries, the standard hero chart.
struct TrendChart: View {
    let points: [MonitoringTrendPoint]
    let range: MonitoringTrendRange
    var tint: Color
    var yDomain: ClosedRange<Double>?
    var height: CGFloat = 132

    private var visiblePoints: [MonitoringTrendPoint] {
        let cutoff = Date().addingTimeInterval(-range.duration)
        return points.filter { $0.timestamp >= cutoff }
    }

    var body: some View {
        let visible = visiblePoints
        Group {
            if visible.count < 2 {
                VStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Collecting samples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: height)
            } else {
                let domain = resolvedDomain(for: visible)
                Chart(visible, id: \.timestamp) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        yStart: .value("Scale minimum", domain.lowerBound),
                        yEnd: .value("Value", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartXScale(
                    domain: Date().addingTimeInterval(-range.duration)...Date(),
                    range: .plotDimension(startPadding: 6, endPadding: 6)
                )
                .chartYScale(
                    domain: domain,
                    range: .plotDimension(startPadding: 6, endPadding: 6)
                )
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute(), anchor: .top)
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: height)
            }
        }
    }

    private func resolvedDomain(for visible: [MonitoringTrendPoint]) -> ClosedRange<Double> {
        if let yDomain { return yDomain }
        let values = visible.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let minimumPadding = 1.5
        guard high > low else { return low - minimumPadding...high + minimumPadding }
        let padding = max((high - low) * 0.15, minimumPadding)
        return (low - padding)...(high + padding)
    }
}

/// Small, axis-free trend used in overview cards and popovers.
struct Sparkline: View {
    let points: [MonitoringTrendPoint]
    var tint: Color
    var height: CGFloat = 34

    var body: some View {
        Group {
            if points.count < 2 {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
                    .frame(height: height)
            } else {
                Chart(points, id: \.timestamp) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.25), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 1.25))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .chartXScale(range: .plotDimension(startPadding: 3, endPadding: 3))
                .chartYScale(range: .plotDimension(startPadding: 3, endPadding: 3))
                .frame(height: height)
            }
        }
    }
}

/// Range picker + Now / Average / Peak strip shown under hero charts.
struct TrendSummaryStrip: View {
    let series: MonitoringTrendSeries
    let range: MonitoringTrendRange
    let format: (Double) -> String

    var body: some View {
        if let summary = series.summary(for: range) {
            HStack(spacing: 0) {
                summaryCell("Now", format(summary.latest))
                summaryDivider
                summaryCell("Average", format(summary.average))
                summaryDivider
                summaryCell("Peak", format(summary.maximum))
                summaryDivider
                summaryCell("Low", format(summary.minimum))
            }
        }
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: 26)
    }

    private func summaryCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.readingSmall.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Status dot

struct StatusDot: View {
    let severity: ReadingSeverity

    var body: some View {
        Circle()
            .fill(severity.color)
            .frame(width: 7, height: 7)
    }
}

// MARK: - Page scaffold

/// Standard scrolling page: title row, then panels with consistent rhythm.
struct MonitorPage<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)

                content
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
