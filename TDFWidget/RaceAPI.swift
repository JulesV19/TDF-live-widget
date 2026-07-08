//
//  RaceAPI.swift
//  TDFWidget
//
//  Récupération de l'état de course auprès du serveur local.
//

import Foundation

enum RaceAPI {
    /// Récupère l'état courant. Retourne `nil` en cas d'erreur réseau/décodage.
    static func fetchCurrent() async -> RaceState? {
        guard let url = ServerConfig.currentURL else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try JSONDecoder().decode(RaceState.self, from: data)
        } catch {
            return nil
        }
    }
}
