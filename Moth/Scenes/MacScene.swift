//  MacScene.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct MacScene: Scene {

    let dependencies: any AppDependencies

    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
    }

}
