//  Variable+Plain.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore

extension Variable {

    static func plain(_ name: String, _ value: String) -> Variable {
        Variable(name: name, value: .plain(initial: value, current: value))
    }

}
