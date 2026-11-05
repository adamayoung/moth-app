//  MacScene.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct MacScene: Scene {

    let dependencies: any AppDependencies

    var body: some Scene {
        WindowGroup {
            Color.clear
                .frame(minWidth: 480, minHeight: 320)
        }
    }

}
