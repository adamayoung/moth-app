//  EnvironmentsObserver.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import SwiftData
import SwiftUI

/// Sits on the window rather than the sidebar, so a collapsed sidebar still feeds the toolbar picker.
struct EnvironmentsObserver: View {

    let model: EnvironmentsModel

    @Query private var environments: [EnvironmentModel]
    @Query private var variables: [VariableModel]

    var body: some View {
        Color.clear
            .onChange(of: summaries, initial: true) { _, newSummaries in
                model.rowsDidChange(newSummaries)
            }
    }

    private var summaries: [EnvironmentSummary] {
        EnvironmentSummary.list(environments: environments, variables: variables)
    }

}
