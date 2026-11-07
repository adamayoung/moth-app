//  CodeAuth.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

nonisolated struct CodeAuth {

    private(set) var header: CodeHeader?
    private(set) var basicCredentials: String?
    private(set) var queryPair: String?
    private(set) var note: String?

    init(_ auth: Auth) {
        switch auth {
        case .inherit, .none:
            break
        case .basic(let basic):
            self.basicCredentials = "\(basic.username):<password>"
        case .bearer:
            self.header = CodeHeader(name: "Authorization", value: "Bearer <token>")
        case .apiKey(let apiKey):
            switch apiKey.location {
            case .header: self.header = CodeHeader(name: apiKey.name, value: "<api-key>")
            case .query: self.queryPair = "\(apiKey.name.urlDisplayEncoded)=<api-key>"
            }
        case .digest:
            self.note = String(localized: "CODE_NOTE_DIGEST", bundle: .module)
        case .oauth2:
            self.note = String(localized: "CODE_NOTE_OAUTH2", bundle: .module)
        case .awsSigV4:
            self.note = String(localized: "CODE_NOTE_AWS", bundle: .module)
        }
    }

    /// The header this auth sets, which replaces a manual one of that name, as it does on Send.
    var headerName: String? {
        basicCredentials == nil ? header?.name : "Authorization"
    }

}
