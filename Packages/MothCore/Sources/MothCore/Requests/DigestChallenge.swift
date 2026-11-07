//  DigestChallenge.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CryptoKit
import Foundation

nonisolated enum DigestAlgorithm: String, CaseIterable, Sendable {

    case md5 = "MD5"
    case md5Session = "MD5-sess"
    case sha256 = "SHA-256"
    case sha256Session = "SHA-256-sess"

    init?(named name: String) {
        guard let algorithm = Self.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(name) == .orderedSame })
        else {
            return nil
        }
        self = algorithm
    }

    var isSession: Bool {
        self == .md5Session || self == .sha256Session
    }

    func hash(_ text: String) -> String {
        let data = Data(text.utf8)
        let digest: any Sequence<UInt8> = switch self {
        case .md5, .md5Session: Insecure.MD5.hash(data: data)
        case .sha256, .sha256Session: SHA256.hash(data: data)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

}

/// One that Moth can answer: a known algorithm, and `auth` among its qop options.
nonisolated struct DigestChallenge: Sendable, Hashable {

    let realm: String
    let nonce: String
    let opaque: String?
    let algorithm: DigestAlgorithm

    init?(_ challenge: AuthChallenge) {
        let parameters = challenge.parameters
        guard
            challenge.isScheme("Digest"),
            let realm = parameters["realm"],
            let nonce = parameters["nonce"],
            let algorithm = DigestAlgorithm(named: parameters["algorithm"] ?? DigestAlgorithm.md5.rawValue),
            Self.offersAuth(parameters["qop"])
        else {
            return nil
        }

        self.realm = realm
        self.nonce = nonce
        self.opaque = parameters["opaque"]
        self.algorithm = algorithm
    }

    static func isOffered(in header: String) -> Bool {
        AuthChallenge.all(in: header).contains { $0.isScheme("Digest") }
    }

    /// Servers list challenges in their order of preference.
    static func first(in header: String) -> DigestChallenge? {
        AuthChallenge.all(in: header).lazy.compactMap(DigestChallenge.init).first
    }

    /// No qop is RFC 2069's form, which RFC 7616 retired.
    private static func offersAuth(_ qop: String?) -> Bool {
        (qop ?? "").split(separator: ",").contains {
            $0.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("auth") == .orderedSame
        }
    }

}
