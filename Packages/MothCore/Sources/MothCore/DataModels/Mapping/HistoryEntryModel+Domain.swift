//  HistoryEntryModel+Domain.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated extension HistoryEntryModel {

    convenience init(_ entry: HistoryEntry) throws {
        self.init()
        self.id = entry.id
        self.requestID = entry.request.id
        self.requestData = try StoredJSON.encode(entry.request)
        self.method = entry.request.method.rawValue
        self.url = RequestDraft(entry.request).url
        self.sentAt = entry.sentAt
        self.durationSeconds = entry.duration.components.seconds
        self.durationAttoseconds = entry.duration.components.attoseconds
        self.failure = entry.failure?.description
        self.failureKind = entry.failure?.kind.rawValue
        if let response = entry.response {
            self.statusCode = response.status
            self.reasonPhrase = response.reasonPhrase
            self.responseHeadersData = try StoredJSON.encode(response.headers)
            self.timingData = try StoredJSON.encode(response.timing)
            self.responseSize = response.size
            self.responseBody = response.body
        }
    }

    func asDomain() throws -> HistoryEntry {
        try HistoryEntry(
            id: id,
            request: StoredJSON.decode(Request.self, from: requestData, default: Request(id: requestID, name: "")),
            sentAt: sentAt,
            duration: duration,
            response: response(),
            failure: sendFailure
        )
    }

    private var duration: Duration {
        Duration(secondsComponent: durationSeconds, attosecondsComponent: durationAttoseconds)
    }

    private var sendFailure: SendFailure? {
        failureKind.map { SendFailure(kind: SendFailure.Kind(rawValue: $0) ?? .couldNotConnect, description: failure) }
    }

    private func response() throws -> HistoryResponse? {
        guard let statusCode else {
            return nil
        }

        return try HistoryResponse(
            status: statusCode,
            reasonPhrase: reasonPhrase,
            headers: StoredJSON.decode([KeyValue].self, from: responseHeadersData, default: []),
            timing: StoredJSON.decode([PhaseTiming].self, from: timingData, default: []),
            size: responseSize,
            body: responseSize > HistoryResponse.bodyLimit ? nil : responseBody ?? Data()
        )
    }

}
