//  MacScene.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct MacScene: Scene {

    let dependencies: any AppDependencies

    var body: some Scene {
        WindowGroup {
            MainWindowView(dataModel: dependencies.dataModel)
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
        }
    }

}
