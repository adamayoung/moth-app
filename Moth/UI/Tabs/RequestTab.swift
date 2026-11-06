//  RequestTab.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore

struct RequestTab: Identifiable, Hashable {

    let id: Request.ID
    let name: String
    let method: HTTPMethod
    var inheritedAuth = InheritedAuth.nothing

}
