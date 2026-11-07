//  HTTPDefaultPort.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated enum HTTPDefaultPort {

    static func of(scheme: String?) -> Int? {
        switch scheme?.lowercased() {
        case "http": 80
        case "https": 443
        default: nil
        }
    }

}
