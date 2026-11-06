//  CollectionModel+Domain.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated extension CollectionModel: StoredAuthRow {

    var storedAuth: Auth {
        get throws {
            try StoredJSON.decode(Auth.self, from: authData, default: .none)
        }
    }

    convenience init(_ collection: RequestCollection, sortOrder: Int) throws {
        self.init()
        self.id = collection.id
        self.name = collection.name
        self.sortOrder = sortOrder
        self.authData = try StoredJSON.encode(collection.auth)
        self.variables = collection.variables.enumerated().map { index, variable in
            VariableModel(variable, sortOrder: index)
        }
        let rows = try ChildRows(collection.children)
        self.folders = rows.folders
        self.requests = rows.requests
    }

    public func asDomain() throws -> RequestCollection {
        try RequestCollection(
            id: id,
            name: name,
            auth: storedAuth,
            variables: variables.inSortOrder.map { $0.asDomain() },
            children: ChildRows.items(folders: folders, requests: requests)
        )
    }

}

nonisolated extension FolderModel: StoredAuthRow {

    var storedAuth: Auth {
        get throws {
            try StoredJSON.decode(Auth.self, from: authData, default: .inherit)
        }
    }

    convenience init(_ folder: Folder, sortOrder: Int) throws {
        self.init()
        self.id = folder.id
        self.name = folder.name
        self.sortOrder = sortOrder
        self.authData = try StoredJSON.encode(folder.auth)
        let rows = try ChildRows(folder.children)
        self.subfolders = rows.folders
        self.requests = rows.requests
    }

    public func asDomain() throws -> Folder {
        try Folder(
            id: id,
            name: name,
            auth: storedAuth,
            children: ChildRows.items(folders: subfolders, requests: requests)
        )
    }

}

private nonisolated struct ChildRows {

    var folders: [FolderModel] = []
    var requests: [RequestModel] = []

    init(_ children: [CollectionItem]) throws {
        for item in children {
            switch item.node {
            case .folder(let folder):
                try folders.append(FolderModel(folder, sortOrder: item.sortOrder))
            case .request(let request):
                try requests.append(RequestModel(request, sortOrder: item.sortOrder))
            }
        }
    }

    /// A folder and a request share one ordering, so their `sortOrder` values interleave.
    static func items(folders: [FolderModel]?, requests: [RequestModel]?) throws -> [CollectionItem] {
        let folderItems = try (folders ?? []).map { row in
            try CollectionItem(sortOrder: row.sortOrder, node: .folder(row.asDomain()))
        }
        let requestItems = try (requests ?? []).map { row in
            try CollectionItem(sortOrder: row.sortOrder, node: .request(row.asDomain()))
        }
        return folderItems + requestItems
    }

}
