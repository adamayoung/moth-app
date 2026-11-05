//  PostmanAuthType.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

public enum PostmanAuthType: Sendable, Equatable {

    case apikey
    case awsv4
    case basic
    case bearer
    case digest
    case edgegrid
    case hawk
    case noauth
    case ntlm
    case oauth1
    case oauth2
    case unknown(String)

    /// The schema lets `noauth` hold anything, and an unknown type's payload has no published shape.
    var allowsAnyPayload: Bool {
        switch self {
        case .noauth, .unknown:
            true
        case .apikey, .awsv4, .basic, .bearer, .digest, .edgegrid, .hawk, .ntlm, .oauth1, .oauth2:
            false
        }
    }

    init(name: String) {
        switch name {
        case "apikey": self = .apikey
        case "awsv4": self = .awsv4
        case "basic": self = .basic
        case "bearer": self = .bearer
        case "digest": self = .digest
        case "edgegrid": self = .edgegrid
        case "hawk": self = .hawk
        case "noauth": self = .noauth
        case "ntlm": self = .ntlm
        case "oauth1": self = .oauth1
        case "oauth2": self = .oauth2
        default: self = .unknown(name)
        }
    }

}
