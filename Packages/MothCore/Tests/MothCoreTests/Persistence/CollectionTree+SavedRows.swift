//  CollectionTree+SavedRows.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

@testable import MothCore
import SwiftData

extension CollectionTree {

    /// A fresh context, because the rows under test were saved by another one.
    init(savedIn dataModel: DataModel) throws {
        let context = ModelContext(dataModel.container)
        try self.init(
            collections: context.fetch(FetchDescriptor<CollectionModel>()),
            folders: context.fetch(FetchDescriptor<FolderModel>()),
            requests: context.fetch(FetchDescriptor<RequestModel>())
        )
    }

}
