//  MacScene.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct MacScene: Scene {

    let dependencies: any AppDependencies

    var body: some Scene {
        WindowGroup {
            MainWindowView(
                dataModel: dependencies.dataModel,
                secretStore: dependencies.secretStore,
                transport: dependencies.transport,
                activeEnvironment: dependencies.activeEnvironment,
                tabStore: dependencies.requestTabStore,
                requestDrafts: dependencies.requestDrafts,
                isSyncedToICloud: dependencies.isSyncedToICloud,
                importFileSource: dependencies.importFileSource
            )
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
            RequestTabCommands()
            ImportCommands()
        }
    }

}
