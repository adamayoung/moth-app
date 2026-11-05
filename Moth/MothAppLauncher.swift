//  MothAppLauncher.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

@main
enum MothAppLauncher {

    static func main() {
        switch DependencyProvider.currentOutcome {
        case .storeFailure: TestHostApp.main()
        case .ready(let provider) where provider.launchMode == .testHost: TestHostApp.main()
        case .ready: MothApp.main()
        }
    }

}
