//
//  RaceKit.swift
//  TDF Live (app hôte)
//
//  Modèle + réseau + config pour la cible APP.
//  (Miroir volontaire des fichiers du même nom dans TDFWidget/ : app et
//  extension sont deux modules distincts, chacun a besoin de ces types.)
//

import Foundation

// MARK: - Config

enum ServerConfig {
    /// IP réseau du Mac (Wi-Fi). Joignable depuis le simulateur ET l'iPhone
    /// tant qu'ils sont sur le même Wi-Fi. Si l'IP du Mac change, mets-la à jour
    /// (ou passe à une IP Tailscale, stable, plus tard).
    static let baseURL = "http://192.168.1.6:8000"
    static var currentURL: URL? { URL(string: baseURL + "/race/current") }
}

// MARK: - Modèle

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

// MARK: - Réseau

enum RaceAPI {
    static func fetchCurrent() async -> RaceState? {
        guard let url = ServerConfig.currentURL else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(RaceState.self, from: data)
        } catch {
            return nil
        }
    }
}
