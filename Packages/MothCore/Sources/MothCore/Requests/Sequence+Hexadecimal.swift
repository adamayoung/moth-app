//  Sequence+Hexadecimal.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension Sequence<UInt8> {

    var hexadecimal: String {
        map { String(format: "%02x", $0) }.joined()
    }

}
