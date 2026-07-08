//
//  LiveView.swift
//  TDF Live (app hôte)
//
//  Vue live plein écran : interroge le serveur toutes les 60 s (calé sur la
//  cadence du serveur, plus sobre pour la batterie) et rafraîchit aussi le
//  widget au passage.
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
    /// Nombre de vélos selon la TAILLE du groupe (solo → 1, petit → 2, paquet → 3).
    static func bikeCount(_ count: Int) -> Int {
        if count <= 1 { return 1 }
        if count <= 8 { return 2 }
        return 3
    }
    static func markerSize(_ count: Int) -> CGFloat { min(26, max(12, 9 + sqrt(Double(count)) * 1.6)) }
}

/// Marqueur d'un groupe : drapeau pour la tête de course, sinon 1 à 3 vélos
/// selon la taille du groupe.
struct GroupIcon: View {
    let isLeader: Bool
    let count: Int
    let size: CGFloat

    var body: some View {
        if isLeader {
            Image(systemName: "flag.checkered")
                .font(.system(size: size, weight: .bold))
        } else {
            HStack(spacing: 1.5) {
                ForEach(0..<L.bikeCount(count), id: \.self) { _ in
                    Image(systemName: "bicycle")
                        .font(.system(size: size, weight: .bold))
                }
            }
        }
    }
}

struct LiveView: View {
    @State private var state: RaceState?
    @State private var failed = false
    @State private var lastUpdate: Date?

    private let interval: TimeInterval = 60

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
            if let s = state, s.live, !s.groups.isEmpty {
                distance(s)
                Frieze(groups: s.groups)
                    .frame(height: 90)
                    .padding(.vertical, 8)
                groupList(s)
            } else if let s = state, !s.live {
                noStage
            } else if failed {
                Spacer()
                Label("Serveur injoignable\nLance ./run.sh sur le Mac",
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

    // Aucune étape en direct : message clair plutôt qu'un spinner infini.
    private var noStage: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "flag.slash")
                .font(.system(size: 40))
                .foregroundStyle(L.yellow.opacity(0.85))
            Text("Pas d'étape en cours")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Reviens pendant une étape du Tour")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Text("TDF").fontWeight(.heavy).foregroundStyle(L.yellow)
                if state?.live == true, let s = state?.stage {
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
                    GroupIcon(isLeader: i == 0, count: g.count, size: 14)
                        .foregroundStyle(L.color(index: i, count: g.count, maxCount: maxCount))
                        .frame(width: 48, alignment: .leading)
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

                    // Bridage horizontal du label selon sa largeur (icônes empilées
                    // sur l'écart) : 1 à 3 vélos ne débordent jamais du cadre.
                    let bikes = i == 0 ? 1 : L.bikeCount(g.count)
                    let iconsW = CGFloat(bikes) * 11 * 1.5 + CGFloat(bikes - 1) * 1.5
                    let textW = CGFloat(g.gapText.count) * 13 * 0.62
                    let labelHalfW = max(iconsW, textW) / 2
                    let margin = labelHalfW + 4
                    let labelX = margin * 2 >= w ? w / 2 : min(max(x, margin), w - margin)

                    Circle().fill(color).frame(width: d, height: d)
                        .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.2))
                        .shadow(color: color.opacity(0.7), radius: 6)
                        .position(x: x, y: midY)

                    VStack(spacing: 2) {
                        GroupIcon(isLeader: i == 0, count: g.count, size: 11)
                        Text(g.gapText).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                    .foregroundStyle(color)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .fixedSize()
                    .position(x: labelX, y: up ? midY - 30 : midY + 30)
                }
            }
        }
        .animation(.easeInOut(duration: 0.6), value: groups.map(\.gap))
    }
}

#Preview {
    LiveView()
}
