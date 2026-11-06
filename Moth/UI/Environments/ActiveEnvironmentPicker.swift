//  ActiveEnvironmentPicker.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import SwiftUI

struct ActiveEnvironmentPicker: View {

    let environments: EnvironmentsModel

    var body: some View {
        Picker("ENVIRONMENT_PICKER_LABEL", selection: selection) {
            Text("ENVIRONMENT_PICKER_NONE")
                .tag(UUID?.none)
            ForEach(environments.rows) { row in
                Text(verbatim: row.name)
                    .tag(UUID?.some(row.id))
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("environmentPicker")
    }

    private var selection: Binding<UUID?> {
        Binding {
            environments.activeID
        } set: { id in
            environments.selectActive(id)
        }
    }

}
