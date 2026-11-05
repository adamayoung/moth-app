//  HistoryEntryModel+Domain.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension HistoryEntryModel {

    convenience init(_ entry: HistoryEntry) throws {
        self.init()
        self.id = entry.id
        self.requestID = entry.request.id
        self.requestData = try StoredJSON.encode(entry.request)
        self.sentAt = entry.sentAt
        self.durationSeconds = entry.duration.components.seconds
        self.durationAttoseconds = entry.duration.components.attoseconds
        self.failure = entry.failure
        if let response = entry.response {
            self.statusCode = response.status
            self.responseHeadersData = try StoredJSON.encode(response.headers)
            self.responseBody = response.body
        }
    }

    public func asDomain() throws -> HistoryEntry {
        try HistoryEntry(
            id: id,
            request: StoredJSON.decode(Request.self, from: requestData, default: Request(id: requestID, name: "")),
            sentAt: sentAt,
            duration: Duration(secondsComponent: durationSeconds, attosecondsComponent: durationAttoseconds),
            response: response(),
            failure: failure
        )
    }

    private func response() throws -> HistoryResponse? {
        guard let statusCode else {
            return nil
        }

        return try HistoryResponse(
            status: statusCode,
            headers: StoredJSON.decode([KeyValue].self, from: responseHeadersData, default: []),
            body: responseBody ?? Data()
        )
    }

}
