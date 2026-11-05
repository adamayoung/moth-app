//  HTTPTransport.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public protocol HTTPTransport: Sendable {

    @concurrent
    func send(_ request: URLRequest) async throws -> HTTPResponse

}
