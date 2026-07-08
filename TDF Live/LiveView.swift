//
//  LiveView.swift
//  TDF Live (app hôte)
//
//  Vue live plein écran : interroge le serveur toutes les 10 s (démo fiable,
//  l'app au premier plan n'a pas le budget limité des widgets) et rafraîchit
//  aussi le widget au passage.
//

import SwiftUI
import WidgetKit

private enum L {
    static let yellow = Color(red: 1.00, green: 0.83, blue: 0.00)
    static let blue = Color(red: 0.45, green: 0.78, blue: 1.0)

    static func color(index: Int, count: Int, maxCount: Int) -> Color {
        if index == 0 { return yellow }
        return count == maxCount ? .white : blue
    }
    static func icon(index: Int, count: Int) -> String {
        if index == 0 { return "flag.checkered" }
        if count <= 1 { return "person.fill" }
        if count <= 8 { return "person.2.fill" }
        return "person.3.fill"
    }
    static func markerSize(_ count: Int) -> CGFloat { min(26, max(12, 9 + sqrt(Double(count)) * 1.6)) }
}

struct LiveView: View {
    @State private var state: RaceState?
    @State private var failed = false
    @State private var lastUpdate: Date?

    private let interval: TimeInterval = 10

    var body: some View {
        ZStack {
            background
            content
                .padding(20)
        }
        .task { await pollLoop() }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.15),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [L.yellow.opacity(0.25), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 320)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if let s = state, !s.groups.isEmpty {
                distance(s)
                Frieze(groups: s.groups)
                    .frame(height: 90)
                    .padding(.vertical, 8)
                groupList(s)
            } else if failed {
                Spacer()
                Label("Serveur injoignable\nLance ./run.sh --mock sur le Mac",
                      systemImage: "wifi.exclamationmark")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Spacer()
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            Spacer(minLength: 0)
            footer
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Text("TDF").fontWeight(.heavy).foregroundStyle(L.yellow)
                if let s = state?.stage {
                    Text("ÉTAPE \(s)").fontWeight(.semibold).foregroundStyle(.white.opacity(0.7))
                }
            }
            .font(.subheadline)
            Spacer()
            if state?.live == true {
                HStack(spacing: 5) {
                    Circle().fill(.red).frame(width: 7, height: 7)
                    Text("DIRECT").font(.caption).fontWeight(.bold).foregroundStyle(.white)
                }
            }
        }
    }

    private func distance(_ s: RaceState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(s.kmToFinish.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            VStack(alignment: .leading, spacing: -2) {
                Text("km").font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text("À PARCOURIR").font(.caption2).fontWeight(.semibold)
                    .tracking(1.5).foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func groupList(_ s: RaceState) -> some View {
        let maxCount = s.groups.map(\.count).max() ?? 0
        return VStack(spacing: 10) {
            ForEach(Array(s.groups.enumerated()), id: \.element.id) { i, g in
                HStack(spacing: 12) {
                    Image(systemName: L.icon(index: i, count: g.count))
                        .font(.subheadline)
                        .foregroundStyle(L.color(index: i, count: g.count, maxCount: maxCount))
                        .frame(width: 22)
                    Text(g.label).fontWeight(.medium).foregroundStyle(.white)
                    Text("\(g.count)").font(.footnote).foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text(g.gapText).fontWeight(.semibold).monospacedDigit()
                        .foregroundStyle(i == 0 ? L.yellow : .white)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 0.8))
            }
        }
    }

    private var footer: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
            Text("Démo · maj toutes les \(Int(interval)) s")
            Spacer()
            if let d = lastUpdate {
                Text(d, style: .time).monospacedDigit()
            }
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.4))
    }

    // MARK: - Polling

    private func pollLoop() async {
        while !Task.isCancelled {
            if let s = await RaceAPI.fetchCurrent() {
                withAnimation(.easeInOut(duration: 0.6)) {
                    state = s
                    failed = false
                }
                lastUpdate = Date()
            } else {
                failed = (state == nil)
            }
            // Pousse aussi une actualisation du widget (au mieux du budget iOS).
            WidgetCenter.shared.reloadAllTimelines()
            try? await Task.sleep(for: .seconds(interval))
        }
    }
}

// MARK: - Frise plein écran (tête à droite)

private struct Frieze: View {
    let groups: [RaceGroup]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let midY = geo.size.height / 2
            let maxGap = max(1, groups.map(\.gap).max() ?? 1)
            let maxCount = groups.map(\.count).max() ?? 0

            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [L.yellow.opacity(0.9), .white.opacity(0.5), .white.opacity(0.12)],
                                         startPoint: .trailing, endPoint: .leading))
                    .frame(height: 4)
                    .position(x: w / 2, y: midY)

                ForEach(Array(groups.enumerated()), id: \.element.id) { i, g in
                    let d = L.markerSize(g.count)
                    let x = min(max(w - w * CGFloat(g.gap) / CGFloat(maxGap), d / 2), w - d / 2)
                    let color = L.color(index: i, count: g.count, maxCount: maxCount)
                    let up = (i % 2 == 0)

                    Circle().fill(color).frame(width: d, height: d)
                        .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.2))
                        .shadow(color: color.opacity(0.7), radius: 6)
                        .position(x: x, y: midY)

                    VStack(spacing: 2) {
                        Image(systemName: L.icon(index: i, count: g.count)).font(.system(size: 11, weight: .bold))
                        Text(g.gapText).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                    .foregroundStyle(color)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .fixedSize()
                    .position(x: min(max(x, 26), w - 26), y: up ? midY - 30 : midY + 30)
                }
            }
        }
        .animation(.easeInOut(duration: 0.6), value: groups.map(\.gap))
    }
}

#Preview {
    LiveView()
}
