//  MothAppLauncher.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

@main
enum MothAppLauncher {

    static func main() {
        switch DependencyProvider.current.launchMode {
        case .testHost: TestHostApp.main()
        case .live, .uiTesting, .demo: MothApp.main()
        }
    }

}
