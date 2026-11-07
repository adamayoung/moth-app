//  BuildOmissions.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated struct BuildOmissions {

    var notices: [RequestBuildNotice] = []
    var leftOut: Set<RequestPart> = []

    mutating func merge(_ other: BuildOmissions) {
        notices += other.notices
        leftOut.formUnion(other.leftOut)
    }

}
