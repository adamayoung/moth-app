//  ImportFileSource.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation

enum ImportFileSource: Equatable {

    case panel
    /// A UI test can't drive the system panel, and the sandboxed app can't read a path on the runner's disk.
    case uiTest(Data)

}
