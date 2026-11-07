//  HTTPDefaultPort.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

public enum HTTPDefaultPort {

    public static func of(scheme: String?) -> Int? {
        switch scheme?.lowercased() {
        case "http": 80
        case "https": 443
        default: nil
        }
    }

}
