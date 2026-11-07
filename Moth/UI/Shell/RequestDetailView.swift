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
                RequestEditorPane(
                    tab: selected,
                    drafts: tabs.drafts,
                    edit: tabs.editDraft,
                    isSending: selected.map { tabs.responses.isSending($0.id) } ?? false,
                    send: { tabs.send($0) },
                    cancelSend: tabs.cancelSend,
                    urlFocusRequests: tabs.urlFocusRequests
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
        .background {
            AlternateTabShortcuts(tabs: tabs)
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
        .focusedSceneValue(
            \.requestTabCommands,
            RequestTabCommandContext(
                tabs: tabs,
                hasOpenTabs: !tabs.openTabs.isEmpty,
                selectedRequest: selected?.id,
                savableRequest: selected.flatMap { tabs.drafts.canSave($0.id) ? $0.id : nil },
                send: tabs.sendCommand,
                canEditURL: tabs.canEditURL,
                canCycleTabs: tabs.canCycleTabs
            )
        )
    }

    private var closeAlertTitle: String {
        String(localized: "CLOSE_TAB_ALERT_TITLE_\(tabs.pendingClose?.name ?? "")")
    }

}

/// The second pair Safari has, which the Request menu can't list: SwiftUI has no hidden menu item. A sheet takes the
/// window's key status, so neither fires behind one.
private struct AlternateTabShortcuts: View {

    let tabs: RequestTabsModel

    var body: some View {
        Group {
            Button("MENU_NEXT_TAB", action: tabs.selectNextTab)
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button("MENU_PREVIOUS_TAB", action: tabs.selectPreviousTab)
                .keyboardShortcut("[", modifiers: [.command, .shift])
        }
        .focusable(false)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

}

#Preview {
    RequestDetailView(tabs: RequestTabsModel(store: .preview, drafts: .preview, responses: .preview, code: .preview))
        .frame(width: 800, height: 600)
}
