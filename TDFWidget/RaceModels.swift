//
//  RaceModels.swift
//  TDFWidget
//
//  Modèle décodé depuis GET /race/current du serveur.
//

import Foundation

struct RaceState: Codable {
    let stage: Int?
    let live: Bool
    let updatedAt: String?
    let kmToFinish: Double?
    let riderCount: Int?
    let groups: [RaceGroup]
}

struct RaceGroup: Codable, Identifiable {
    let label: String
    let gap: Int
    let gapText: String
    let count: Int
    let riders: [Rider]?

    var id: String { "\(label)-\(gap)" }
}

struct Rider: Codable, Identifiable {
    let bib: Int
    let name: String
    let team: String?
    let kph: Double?

    var id: Int { bib }
}

// MARK: - Données d'exemple (previews / placeholder)

extension RaceState {
    static let sample = RaceState(
        stage: 5,
        live: true,
        updatedAt: "2026-07-08T14:32:10Z",
        kmToFinish: 42.7,
        riderCount: 170,
        groups: [
            RaceGroup(label: "Tête", gap: 0, gapText: "0:00", count: 3,
                      riders: [Rider(bib: 34, name: "SIMMONS", team: "LIDL-TREK", kph: 42.0)]),
            RaceGroup(label: "Groupe 2", gap: 48, gapText: "+0:48", count: 6, riders: nil),
            RaceGroup(label: "Peloton", gap: 135, gapText: "+2:15", count: 147, riders: nil),
            RaceGroup(label: "Groupe 4", gap: 520, gapText: "+8:40", count: 20, riders: nil),
        ]
    )

    static let idle = RaceState(
        stage: 5, live: false, updatedAt: nil, kmToFinish: nil,
        riderCount: 0, groups: []
    )
}
