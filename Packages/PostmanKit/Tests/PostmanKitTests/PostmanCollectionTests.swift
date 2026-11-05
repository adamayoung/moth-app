//  PostmanCollectionTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import PostmanKit
import Testing

struct PostmanCollectionTests {

    @Test("An app export decodes its name, nested folders and request in file order")
    func decodesAppExportStructure() throws {
        let collection = try Fixture.collection("openapi-to-postman/collection.json")

        #expect(collection.info.name == "this")
        let folderOne = try #require(collection.items.only?.folder)
        #expect(folderOne.name == "folder 1")
        let folderTwo = try #require(folderOne.items.only?.folder)
        #expect(folderTwo.name == "folder 1.2")
        let folderThree = try #require(folderTwo.items.only?.folder)
        #expect(folderThree.name == "folder 1.2.1")
        let request = try #require(folderThree.items.only?.requestItem)
        #expect(request.name == "Read a spacecraft")
        #expect(request.request.method == "GET")
    }

    @Test("A collection's requests keep file order")
    func keepsFileOrder() throws {
        let collection = try Fixture.collection("postman-code-generators/basicCollection.json")

        #expect(collection.items.requestItems.map(\.name) == [
            "Request Headers (With special Characters)",
            "Request Headers",
            "Request Headers with disabled headers",
            "GET Request with disabled query",
            "POST Raw Text",
            "POST json with raw",
            "POST graphql body(json) with raw",
            "POST javascript with raw",
            "POST text/xml with raw",
            "POST text/html with raw",
            "POST urlencoded data",
            "PUT Request",
            "PATCH Request",
            "DELETE Request"
        ])
    }

    @Test("Fields PostmanKit doesn't know are ignored, in a real file that holds them")
    func ignoresUnknownFields() throws {
        let path = "openapi-to-postman/collection.json"
        let text = try String(decoding: Fixture.data(path), as: UTF8.self)
        #expect(text.contains("_exporter_id"))
        #expect(text.contains("_postman_previewlanguage"))

        let collection = try Fixture.collection(path)

        #expect(collection.info.name == "this")
    }

    @Test("A v2.0.0 collection is rejected and the error names its schema")
    func rejectsV20AndNamesTheSchema() {
        let schema = "https://schema.getpostman.com/json/collection/v2.0.0/collection.json"

        #expect(throws: PostmanDecodingError.unsupportedSchema(found: schema)) {
            try Fixture.collection("postman-collection-transformer/v2.1.0/proper-description-parsing.json")
        }
    }

    @Test("A v1 collection is rejected and the error reports that it found no schema")
    func rejectsV1WithNoSchema() {
        #expect(throws: PostmanDecodingError.unsupportedSchema(found: nil)) {
            try Fixture.collection("postman-collection-transformer/v1.0.0/binary-upload.json")
        }
    }

}
