//  Duration+TimeInterval.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension Duration {

    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components

        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }

}
