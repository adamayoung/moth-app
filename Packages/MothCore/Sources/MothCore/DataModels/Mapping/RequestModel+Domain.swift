//  RequestModel+Domain.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated extension RequestModel: StoredAuthRow {

    var storedAuth: Auth {
        get throws {
            try StoredJSON.decode(Auth.self, from: authData, default: .inherit)
        }
    }

    convenience init(_ request: Request, sortOrder: Int) throws {
        self.init()
        self.id = request.id
        self.name = request.name
        self.methodRawValue = request.method.rawValue
        self.urlTemplate = request.urlTemplate
        self.sortOrder = sortOrder
        self.queryParametersData = try StoredJSON.encode(request.queryParameters)
        self.pathParametersData = try StoredJSON.encode(request.pathParameters)
        self.headersData = try StoredJSON.encode(request.headers)
        self.bodyData = try StoredJSON.encode(request.body)
        self.authData = try StoredJSON.encode(request.auth)
        self.settingsData = try StoredJSON.encode(request.settings)
        self.variables = request.variables.enumerated().map { index, variable in
            VariableModel(variable, sortOrder: index)
        }
    }

    /// Rewrites a body or auth only when it changed, because encoding a decoded value drops any key this build can't
    /// read.
    func apply(_ edit: RequestEdit, from base: RequestEdit) throws {
        assign(edit.method.rawValue, to: \.methodRawValue)
        assign(edit.urlTemplate, to: \.urlTemplate)
        try assign(StoredJSON.encode(edit.queryParameters), to: \.queryParametersData)
        try assign(StoredJSON.encode(edit.pathParameters), to: \.pathParametersData)
        try assign(StoredJSON.encode(edit.headers), to: \.headersData)
        if edit.body != base.body {
            try assign(StoredJSON.encode(edit.body), to: \.bodyData)
        }
        if edit.auth != base.auth {
            try assign(StoredJSON.encode(edit.auth), to: \.authData)
        }
    }

    /// An equal value still counts as a change to a row, and a sync would carry it to every Mac.
    private func assign<Value: Equatable>(_ value: Value, to property: ReferenceWritableKeyPath<RequestModel, Value>) {
        if self[keyPath: property] != value {
            self[keyPath: property] = value
        }
    }

    public func asDomain() throws -> Request {
        try Request(
            id: id,
            name: name,
            method: HTTPMethod(rawValue: methodRawValue),
            urlTemplate: urlTemplate,
            queryParameters: StoredJSON.decode([KeyValue].self, from: queryParametersData, default: []),
            pathParameters: StoredJSON.decode([KeyValue].self, from: pathParametersData, default: []),
            headers: StoredJSON.decode([KeyValue].self, from: headersData, default: []),
            body: StoredJSON.decode(RequestBody.self, from: bodyData, default: .none),
            auth: storedAuth,
            settings: StoredJSON.decode(RequestSettings.self, from: settingsData, default: RequestSettings()),
            variables: variables.inSortOrder.map { $0.asDomain() }
        )
    }

}
