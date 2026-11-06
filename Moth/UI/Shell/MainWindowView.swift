//  MainWindowView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct MainWindowView: View {

    let isSyncedToICloud: Bool

    var body: some View {
        NavigationSplitView {
            SidebarView(isSyncedToICloud: isSyncedToICloud)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            VStack(spacing: 0) {
                TabStripView()
                Divider()
                VSplitView {
                    RequestEditorPane()
                        .frame(minHeight: 160)
                    ResponsePane()
                        .frame(minHeight: 160)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }

}

#Preview {
    MainWindowView(isSyncedToICloud: false)
        .frame(width: 1100, height: 720)
}
