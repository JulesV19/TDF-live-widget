//
//  ServerConfig.swift
//  TDFWidget
//
//  Adresse du serveur TDF live (celui lancé sur ton Mac).
//

import Foundation

enum ServerConfig {
    /// Worker Cloudflare qui relaie le snapshot : joignable de PARTOUT (4G, autre
    /// Wi-Fi…), en HTTPS, sans VPN. Remplace <ton-sous-domaine> par l'URL affichée
    /// par `wrangler deploy` (voir cloudflare/README.md).
    /// Repli réseau local : "http://192.168.1.6:8000"
    static let baseURL = "https://tdf-live.juckles.workers.dev"

    static var currentURL: URL? { URL(string: baseURL + "/race/current") }
}
