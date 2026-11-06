//  RequestEditorObserver.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import OSLog
import SwiftData
import SwiftUI

/// One row, for the selected tab, because decoding every request's JSON on each delivery would read every body.
struct RequestEditorObserver: View {

    private enum StoredRequest: Equatable {

        case absent
        case readable(Request)
        case unreadable

    }

    let id: Request.ID
    let drafts: RequestDrafts

    @Query private var rows: [RequestModel]

    init(id: Request.ID, drafts: RequestDrafts) {
        self.id = id
        self.drafts = drafts
        self._rows = Query(RequestModel.withID(id))
    }

    var body: some View {
        Color.clear
            .onChange(of: storedRequest, initial: true) { _, stored in
                switch stored {
                case .absent: break
                case .readable(let request): drafts.savedRequestDidChange(request)
                case .unreadable: drafts.savedRequestIsUnreadable(id)
                }
            }
    }

    private var storedRequest: StoredRequest {
        guard let row = rows.first else {
            return .absent
        }
        do {
            return try .readable(row.asDomain())
        } catch {
            Logger.editor.error("Reading a request failed: \(String(describing: error), privacy: .private)")
            return .unreadable
        }
    }

}
