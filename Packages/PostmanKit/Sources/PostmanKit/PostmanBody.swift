//  PostmanBody.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public enum PostmanBody: Decodable, Sendable, Equatable {

    case raw(String?, language: String?)
    case urlencoded([PostmanKeyValue])
    case formdata([PostmanFormDataRow])
    case file(src: String?, content: String?)
    case graphql(query: String?, variables: PostmanValue?)
    case empty
    case unknown(String)

    private enum CodingKeys: String, CodingKey {
        case mode
        case raw
        case urlencoded
        case formdata
        case file
        case graphql
        case options
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let mode = try container.decodeIfPresent(String.self, forKey: .mode) else {
            self = .empty
            return
        }
        switch mode {
        case "raw":
            let options = try container.decodeIfPresent(BodyOptions.self, forKey: .options)
            let text = try container.decodeIfPresent(String.self, forKey: .raw)
            self = .raw(text, language: options?.raw?.language)
        case "urlencoded":
            self = try .urlencoded(container.decodeList(forKey: .urlencoded))
        case "formdata":
            self = try .formdata(container.decodeList(forKey: .formdata))
        case "file":
            let file = try container.decodeIfPresent(FileBody.self, forKey: .file)
            self = .file(src: file?.src, content: file?.content)
        case "graphql":
            let graphql = try container.decodeIfPresent(GraphQLBody.self, forKey: .graphql)
            self = .graphql(query: graphql?.query, variables: graphql?.variables)
        default:
            self = .unknown(mode)
        }
    }

}

private struct BodyOptions: Decodable {

    struct RawOptions: Decodable {

        let language: String?

    }

    let raw: RawOptions?

}

private struct FileBody: Decodable {

    let src: String?
    let content: String?

}

private struct GraphQLBody: Decodable {

    let query: String?
    let variables: PostmanValue?

}
