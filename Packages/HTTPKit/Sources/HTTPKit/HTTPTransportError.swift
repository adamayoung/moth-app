//  HTTPTransportError.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public enum HTTPTransportError: Error, Equatable {
    case timedOut(description: String)
    case connectionFailed(description: String)
    case tlsFailed(description: String)
    case failed(description: String)
    case notHTTP
}

extension HTTPTransportError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .timedOut(let description),
             .connectionFailed(let description),
             .tlsFailed(let description),
             .failed(let description):
            description

        case .notHTTP:
            nil
        }
    }

}

extension HTTPTransportError {

    static func translating(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError:
            error

        case let urlError as URLError where urlError.code == .cancelled:
            CancellationError()

        case let urlError as URLError:
            HTTPTransportError(urlError)

        default:
            HTTPTransportError.failed(description: error.localizedDescription)
        }
    }

    private init(_ error: URLError) {
        let description = error.localizedDescription
        switch error.code {
        case .timedOut:
            self = .timedOut(description: description)

        case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed,
             .notConnectedToInternet, .internationalRoamingOff, .callIsActive, .dataNotAllowed:
            self = .connectionFailed(description: description)

        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected,
             .clientCertificateRequired:
            self = .tlsFailed(description: description)

        default:
            self = .failed(description: description)
        }
    }

}
