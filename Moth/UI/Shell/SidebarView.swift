//  SidebarView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct SidebarView: View {

    let isSyncedToICloud: Bool

    var body: some View {
        List {
            Section("SIDEBAR_COLLECTIONS_SECTION") {
                ContentUnavailableView {
                    Text("SIDEBAR_COLLECTIONS_EMPTY")
                }
            }

            Section("SIDEBAR_ENVIRONMENTS_SECTION") {
                ContentUnavailableView {
                    Text("SIDEBAR_ENVIRONMENTS_EMPTY")
                }
            }

            Section("SIDEBAR_HISTORY_SECTION") {
                ContentUnavailableView {
                    Text("SIDEBAR_HISTORY_EMPTY")
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("sidebar")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isSyncedToICloud {
                ICloudSyncOffFooter()
            }
        }
    }

}

#Preview("Synced") {
    SidebarView(isSyncedToICloud: true)
        .frame(width: 240, height: 500)
}

#Preview("iCloud Sync Off") {
    SidebarView(isSyncedToICloud: false)
        .frame(width: 240, height: 500)
}
