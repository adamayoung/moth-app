//  CookieCommands.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

extension FocusedValues {

    @Entry var cookiesModel: CookiesModel?

}

struct CookieCommands: Commands {

    @FocusedValue(\.cookiesModel) private var model

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("MENU_MANAGE_COOKIES") {
                if let model {
                    Task { await model.open() }
                }
            }
            .disabled(model == nil || model?.isPresented == true)
        }
    }

}
