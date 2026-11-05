//  RequestModel+Domain.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated extension RequestModel {

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
            auth: StoredJSON.decode(Auth.self, from: authData, default: .inherit),
            settings: StoredJSON.decode(RequestSettings.self, from: settingsData, default: RequestSettings()),
            variables: variables.inSortOrder.map { $0.asDomain() }
        )
    }

}
