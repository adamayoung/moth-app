//  RequestDetailView.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import SwiftUI

/// Reads the tabs here, not in `MainWindowView`, because a change there would hand `CollectionTreeObserver` a new
/// closure
/// and walk every row on every tab click.
struct RequestDetailView: View {

    @Bindable var tabs: RequestTabsModel

    var body: some View {
        let selected = tabs.selectedTab

        VStack(spacing: 0) {
            TabStripView(tabs: tabs)
            Divider()
            VSplitView {
                RequestEditorPane(tab: selected, drafts: tabs.drafts, edit: tabs.editDraft)
                    .frame(minHeight: 250)
                ResponsePane()
                    .frame(minHeight: 160)
            }
        }
        .background {
            if let selected {
                RequestEditorObserver(id: selected.id, drafts: tabs.drafts)
                    .id(selected.id)
            }
        }
        .alert(closeAlertTitle, item: $tabs.pendingClose) { tab in
            Button("CLOSE_TAB_ALERT_SAVE") {
                Task { await tabs.saveAndClose(tab.id) }
            }
            Button("CLOSE_TAB_ALERT_DONT_SAVE", role: .destructive) {
                tabs.discardAndClose(tab.id)
            }
            Button("CLOSE_TAB_ALERT_CANCEL", role: .cancel) {}
        }
        .focusedSceneValue(
            \.requestTabCommands,
            RequestTabCommandContext(
                tabs: tabs,
                hasOpenTabs: !tabs.openTabs.isEmpty,
                savableRequest: selected.flatMap { tabs.drafts.canSave($0.id) ? $0.id : nil }
            )
        )
    }

    private var closeAlertTitle: String {
        String(localized: "CLOSE_TAB_ALERT_TITLE_\(tabs.pendingClose?.name ?? "")")
    }

}

#Preview {
    RequestDetailView(tabs: RequestTabsModel(store: .preview, drafts: RequestDrafts.preview))
        .frame(width: 800, height: 600)
}
