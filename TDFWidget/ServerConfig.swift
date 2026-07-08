//
//  ServerConfig.swift
//  TDFWidget
//
//  Adresse du serveur TDF live (celui lancé sur ton Mac).
//

import Foundation

enum ServerConfig {
    /// IP réseau du Mac (Wi-Fi). Joignable depuis le simulateur ET l'iPhone
    /// tant qu'ils sont sur le même Wi-Fi. Si l'IP du Mac change, mets-la à jour
    /// (ou passe à une IP Tailscale, stable, plus tard).
    static let baseURL = "http://192.168.1.6:8000"

    static var currentURL: URL? { URL(string: baseURL + "/race/current") }
}
