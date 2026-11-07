//  PostmanImportSummary.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated extension PostmanImportResult {

    var importedSummary: String {
        switch content {
        case .collection:
            String(
                localized: "IMPORT_SUMMARY_COLLECTION_\(name)_\(imported.requests)_\(imported.folders)",
                bundle: .module
            )
        case .environment:
            String(localized: "IMPORT_SUMMARY_ENVIRONMENT_\(name)_\(imported.variables)", bundle: .module)
        }
    }

    var skippedSummary: String? {
        skipped.summary
    }

}

nonisolated extension PostmanSkippedCounts {

    var summary: String? {
        let items = countedKinds + skippedAuth
        guard !items.isEmpty else {
            return nil
        }
        return String(localized: "IMPORT_SKIPPED_\(items.catalogList)", bundle: .module)
    }

    private var countedKinds: [String] {
        [
            (scripts, String(localized: "IMPORT_SKIPPED_SCRIPTS_\(scripts)", bundle: .module)),
            (folderVariables, String(localized: "IMPORT_SKIPPED_FOLDER_VARIABLES_\(folderVariables)", bundle: .module)),
            (descriptions, String(localized: "IMPORT_SKIPPED_DESCRIPTIONS_\(descriptions)", bundle: .module)),
            (bodies, String(localized: "IMPORT_SKIPPED_BODIES_\(bodies)", bundle: .module)),
            (
                exampleResponses,
                String(localized: "IMPORT_SKIPPED_EXAMPLE_RESPONSES_\(exampleResponses)", bundle: .module)
            )
        ]
            .filter { count, _ in count > 0 }
            .map { _, text in text }
    }

    private var skippedAuth: [String] {
        auth
            .map { kind, count in (name: kind.displayName, count: count) }
            .sorted { $0.name < $1.name }
            .map { String(localized: "IMPORT_SKIPPED_AUTH_\($0.count)_\($0.name)", bundle: .module) }
    }

}

private nonisolated extension PostmanAuthKind {

    var displayName: String {
        switch self {
        case .awsSigV4: String(localized: "IMPORT_AUTH_AWS_SIGV4", bundle: .module)
        case .digest: String(localized: "IMPORT_AUTH_DIGEST", bundle: .module)
        case .edgeGrid: String(localized: "IMPORT_AUTH_EDGEGRID", bundle: .module)
        case .hawk: String(localized: "IMPORT_AUTH_HAWK", bundle: .module)
        case .ntlm: String(localized: "IMPORT_AUTH_NTLM", bundle: .module)
        case .oauth1: String(localized: "IMPORT_AUTH_OAUTH1", bundle: .module)
        case .oauth2: String(localized: "IMPORT_AUTH_OAUTH2", bundle: .module)
        case .other(let name): name
        }
    }

}
