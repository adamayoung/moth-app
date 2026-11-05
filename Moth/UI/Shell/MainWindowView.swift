//  MainWindowView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

struct MainWindowView: View {

    var body: some View {
        NavigationSplitView {
            SidebarView()
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
    MainWindowView()
        .frame(width: 1100, height: 720)
}
