//  AuthorizationSheetTarget.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore

struct AuthorizationSheetTarget: Identifiable, Hashable {

    let container: TreeContainerID
    let title: String
    let auth: Auth
    let inherited: InheritedAuth

    var id: TreeContainerID {
        container
    }

}
