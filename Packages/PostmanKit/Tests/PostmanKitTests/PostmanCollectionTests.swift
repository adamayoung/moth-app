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
