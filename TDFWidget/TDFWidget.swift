//
//  TDFWidget.swift
//  TDFWidget
//
//  Widget Tour de France — style « liquid glass » :
//  distance restante + frise des écarts (indications directement sur la ligne).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct RaceEntry: TimelineEntry {
    let date: Date
    let state: RaceState?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RaceEntry {
        RaceEntry(date: .now, state: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (RaceEntry) -> Void) {
        if context.isPreview {
            completion(RaceEntry(date: .now, state: .sample))
            return
        }
        Task {
            let state = await RaceAPI.fetchCurrent()
            completion(RaceEntry(date: .now, state: state))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RaceEntry>) -> Void) {
        Task {
            let state = await RaceAPI.fetchCurrent()
            let entry = RaceEntry(date: .now, state: state)
            let ahead: TimeInterval = (state?.live == true) ? 15 * 60 : 30 * 60
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(ahead))))
        }
    }
}

// MARK: - Palette & style

private enum Style {
    static let yellow = Color(red: 1.00, green: 0.83, blue: 0.00)
    static let blue = Color(red: 0.45, green: 0.78, blue: 1.0)
    static let ink = Color.white
    static let inkSoft = Color.white.opacity(0.62)
    static let inkFaint = Color.white.opacity(0.35)

    /// Icône selon la TAILLE du groupe (solo / petit groupe / gros paquet).
    static func icon(forCount c: Int) -> String {
        if c <= 1 { return "person.fill" }
        if c <= 8 { return "person.2.fill" }
        return "person.3.fill"
    }

    static func markerSize(_ count: Int) -> CGFloat {
        min(16, max(9, 7 + sqrt(Double(count)) * 1.1))
    }
}

// MARK: - Verre (liquid glass)

private struct GlassPanel<S: Shape>: View {
    let shape: S
    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay(
                shape.stroke(
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.06)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }
}

private extension View {
    func glass<S: Shape>(_ shape: S) -> some View { background(GlassPanel(shape: shape)) }
}

private struct TDFBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.11, blue: 0.15),
                         Color(red: 0.03, green: 0.03, blue: 0.05)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(
                colors: [Style.yellow.opacity(0.28), .clear],
                center: .topLeading, startRadius: 0, endRadius: 210)
        }
    }
}

// MARK: - Routage par famille

struct TDFWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenView(state: entry.state)
        case .systemSmall:
            SmallView(state: entry.state)
        default:
            MediumView(state: entry.state)
        }
    }
}

// MARK: - Frise des écarts (indications sur la ligne)

private struct GapAxis: View {
    let groups: [RaceGroup]
    var compact = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let midY = geo.size.height / 2
            let maxGap = max(1, groups.map(\.gap).max() ?? 1)
            let maxCount = groups.map(\.count).max() ?? 0
            let clearance: CGFloat = compact ? 6 : 9
            let iconSize: CGFloat = compact ? 8 : 9
            let textSize: CGFloat = compact ? 9.5 : 11

            ZStack {
                // Rail : tête de course à DROITE (jaune), attardés à gauche
                Capsule()
                    .fill(LinearGradient(
                        colors: [Style.yellow.opacity(0.9), .white.opacity(0.5), .white.opacity(0.12)],
                        startPoint: .trailing, endPoint: .leading))
                    .frame(height: 3)
                    .position(x: w / 2, y: midY)

                ForEach(Array(groups.enumerated()), id: \.element.id) { i, g in
                    let d = Style.markerSize(g.count)
                    // Inversion : gap 0 (tête) → droite ; gap max → gauche
                    let raw = w - w * CGFloat(g.gap) / CGFloat(maxGap)
                    let x = min(max(raw, d / 2), w - d / 2)
                    let up = (i % 2 == 0)                       // alterne haut / bas
                    let isLeader = (i == 0)                     // groupe de tête (gap mini)
                    let color: Color = isLeader ? Style.yellow
                        : (g.count == maxCount ? .white : Style.blue)
                    let icon = isLeader ? "flag.checkered" : Style.icon(forCount: g.count)
                    // Décalage dynamique, BORNÉ au cadre : le texte ne sort jamais.
                    let labelHalf = textSize / 2 + 4
                    let desired = d / 2 + clearance + textSize / 2
                    let offset = max(min(desired, midY - labelHalf - 1), 0)

                    // Point sur la ligne
                    Circle()
                        .fill(color)
                        .frame(width: d, height: d)
                        .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1))
                        .shadow(color: color.opacity(0.7), radius: 5)
                        .position(x: x, y: midY)

                    // Indication : icône + écart, décollée du point
                    HStack(spacing: 3) {
                        Image(systemName: icon)
                            .font(.system(size: iconSize, weight: .bold))
                        Text(g.gapText)
                            .font(.system(size: textSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(color)
                    .fixedSize()
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .position(x: min(max(x, 24), w - 24),
                              y: up ? midY - offset : midY + offset)
                }
            }
        }
    }
}

// MARK: - Éléments communs

private struct HeaderChip: View {
    let state: RaceState?
    var compact = false
    var body: some View {
        HStack(spacing: 5) {
            Text("TDF").font(.caption2).fontWeight(.heavy).foregroundStyle(Style.yellow)
            if let s = state?.stage {
                Text(compact ? "· \(s)" : "ÉTAPE \(s)")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(Style.inkSoft).tracking(0.5)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 8).padding(.vertical, 4)
        .glass(Capsule())
    }
}

private struct LiveBadge: View {
    let live: Bool
    var compact = false
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(live ? .red : Style.inkFaint).frame(width: 6, height: 6)
            if !compact {
                Text(live ? "DIRECT" : "OFF").font(.caption2).fontWeight(.bold)
                    .foregroundStyle(live ? Style.ink : Style.inkFaint).tracking(0.5)
            }
        }
        .fixedSize()
    }
}

private struct DistanceHero: View {
    let km: Double?
    var size: CGFloat = 42
    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(km.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundStyle(Style.ink)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text("km").font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(Style.inkSoft)
            }
            Text("À PARCOURIR").font(.caption2).fontWeight(.semibold)
                .tracking(1.5).foregroundStyle(Style.inkFaint)
        }
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "bicycle").font(.title2).foregroundStyle(Style.inkFaint)
            Text("Pas de course\nen direct").font(.caption).multilineTextAlignment(.center)
                .foregroundStyle(Style.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small

private struct SmallView: View {
    let state: RaceState?
    private var groups: [RaceGroup] { state?.groups ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HeaderChip(state: state, compact: true)
                Spacer(minLength: 4)
                LiveBadge(live: state?.live ?? false, compact: true)
            }
            if groups.isEmpty {
                EmptyState()
            } else {
                DistanceHero(km: state?.kmToFinish, size: 30)
                GapAxis(groups: Array(groups.prefix(3)), compact: true)
                    .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Medium

private struct MediumView: View {
    let state: RaceState?
    private var groups: [RaceGroup] { state?.groups ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Rangée unique : héros à gauche, en-tête + statut à droite
            HStack(alignment: .top) {
                DistanceHero(km: state?.kmToFinish, size: 34)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    LiveBadge(live: state?.live ?? false)
                    HeaderChip(state: state)
                }
            }
            if groups.isEmpty {
                EmptyState()
            } else {
                GapAxis(groups: Array(groups.prefix(4)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glass(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

// MARK: - Écran verrouillé (monochrome, système)

private struct LockScreenView: View {
    let state: RaceState?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "bicycle")
                Text(distanceText).fontWeight(.bold)
                Spacer()
                if state?.live == true { Text("• DIRECT").font(.caption2) }
            }
            if let groups = state?.groups, !groups.isEmpty {
                MiniAxis(groups: groups).frame(height: 6)
                Text(groups.prefix(3).map { "\($0.label) \($0.gapText)" }.joined(separator: "  ·  "))
                    .font(.caption2).lineLimit(1)
            } else {
                Text("Pas de course en direct").font(.caption2)
            }
        }
        .widgetAccentable()
    }

    private var distanceText: String {
        state?.kmToFinish.map { String(format: "%.1f km", $0) } ?? "— km"
    }
}

private struct MiniAxis: View {
    let groups: [RaceGroup]
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let maxGap = max(1, groups.map(\.gap).max() ?? 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary).frame(height: 2).position(x: w / 2, y: geo.size.height / 2)
                ForEach(Array(groups.enumerated()), id: \.element.id) { _, g in
                    let x = min(max(w - w * CGFloat(g.gap) / CGFloat(maxGap), 3), w - 3)
                    Circle().fill(.primary).frame(width: 6, height: 6)
                        .position(x: x, y: geo.size.height / 2)
                }
            }
        }
    }
}

// MARK: - Configuration

struct TDFWidget: Widget {
    let kind = "TDFWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TDFWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { TDFBackground() }
        }
        .configurationDisplayName("Tour de France")
        .description("Distance restante et écarts entre les groupes.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    TDFWidget()
} timeline: {
    RaceEntry(date: .now, state: .sample)
    RaceEntry(date: .now, state: .idle)
}

#Preview("Small", as: .systemSmall) {
    TDFWidget()
} timeline: {
    RaceEntry(date: .now, state: .sample)
}
