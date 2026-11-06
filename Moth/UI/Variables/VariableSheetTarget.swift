//  VariableSheetTarget.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore

struct VariableSheetTarget: Identifiable, Hashable {

    let scope: VariableScope
    let title: String

    var id: VariableScope {
        scope
    }

}
