//  MothApp.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct MothApp: App {

    private let dependencies = DependencyProvider.current.dependencies

    var body: some Scene {
        MacScene(dependencies: dependencies)
    }

}
