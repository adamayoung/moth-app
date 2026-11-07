//  CookieHeader.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public enum CookieHeader {

    /// A cookie the person typed wins over the jar's cookie of that name.
    public static func merging(manual: String?, jar: [Cookie]) -> String? {
        let manual = manual?.trimmingCharacters(in: .whitespaces) ?? ""
        let typedNames = Set(manual.split(separator: ";").map { pair in
            pair.split(separator: "=", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        })
        let pairs = jar.filter { !typedNames.contains($0.name) }.map { "\($0.name)=\($0.value)" }
        let parts = (manual.isEmpty ? [] : [manual]) + pairs
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

}
