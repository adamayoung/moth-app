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
    var isShowing = true

    var body: some View {
        let selected = tabs.selectedTab

        VStack(spacing: 0) {
            TabStripView(tabs: tabs)
            Divider()
            VSplitView {
                RequestEditorPane(
                    tab: selected,
                    drafts: tabs.drafts,
                    edit: tabs.editDraft,
                    isSending: selected.map { tabs.responses.isSending($0.id) } ?? false,
                    send: { tabs.send($0) },
                    cancelSend: tabs.cancelSend,
                    urlFocusRequests: tabs.urlFocusRequests,
                    accessToken: tabs.accessTokenControls
                )
                .frame(minHeight: 250)
                ResponsePane(state: selected.flatMap { tabs.responses.state(for: $0.id) })
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
        .sheet(item: Bindable(tabs.code).presented) { target in
            GenerateCodeSheet(code: target.code, copy: tabs.code.copy)
        }
        .alert("GENERATE_CODE_FAILED", isPresented: Bindable(tabs.code).hasFailed) {
            Button("GENERATE_CODE_FAILED_OK", role: .cancel) {}
        }
        .focusedSceneValue(\.requestTabCommands, RequestTabCommandContext(tabs: tabs, isShowing: isShowing))
    }

    private var closeAlertTitle: String {
        String(localized: "CLOSE_TAB_ALERT_TITLE_\(tabs.pendingClose?.name ?? "")")
    }

}

#Preview {
    RequestDetailView(tabs: RequestTabsModel(store: .preview, drafts: .preview, responses: .preview, code: .preview))
        .frame(width: 800, height: 600)
}
