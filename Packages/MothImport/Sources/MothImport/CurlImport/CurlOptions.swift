//  CurlOptions.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

nonisolated enum CurlOption {

    case request
    case header
    case data
    case dataRaw
    case dataURLEncode
    case form
    case get
    case userAgent
    case referer
    case cookie
    case url
    case user
    case location
    case insecure
    case compressed

    private static let byLongName: [String: CurlOption] = [
        "request": .request,
        "header": .header,
        "data": .data,
        "data-ascii": .data,
        "data-binary": .data,
        "data-raw": .dataRaw,
        "data-urlencode": .dataURLEncode,
        "form": .form,
        "get": .get,
        "user-agent": .userAgent,
        "referer": .referer,
        "cookie": .cookie,
        "url": .url,
        "user": .user,
        "location": .location,
        "insecure": .insecure,
        "compressed": .compressed
    ]

    private static let byShortName: [Character: CurlOption] = [
        "X": .request,
        "H": .header,
        "d": .data,
        "F": .form,
        "G": .get,
        "A": .userAgent,
        "e": .referer,
        "b": .cookie,
        "u": .user,
        "L": .location,
        "k": .insecure
    ]

    init?(long name: String) {
        guard let option = Self.byLongName[name] else {
            return nil
        }
        self = option
    }

    init?(short name: Character) {
        guard let option = Self.byShortName[name] else {
            return nil
        }
        self = option
    }

    var takesValue: Bool {
        switch self {
        case .get, .location, .insecure, .compressed: false
        default: true
        }
    }

}

/// The flags Moth ignores that take a value, from curl 8.7.1's `--help all`, because that value isn't the URL.
nonisolated enum IgnoredCurlOptions {

    private static let shortNamesTakingValues: Set<Character> = [
        "C", "D", "E", "K", "P", "Q", "T", "U", "Y", "c", "m", "o", "r", "t", "w", "x", "y", "z"
    ]

    private static let longNamesTakingValues: Set<String> = [
        "abstract-unix-socket", "alt-svc", "aws-sigv4", "cacert", "capath", "cert", "cert-type", "ciphers", "config",
        "connect-timeout", "connect-to", "continue-at", "cookie-jar", "create-file-mode", "crlfile", "curves",
        "delegation", "dns-interface", "dns-ipv4-addr", "dns-ipv6-addr", "dns-servers", "doh-url", "dump-header",
        "ech", "egd-file", "engine", "etag-compare", "etag-save", "expect100-timeout", "form-string", "ftp-account",
        "ftp-alternative-to-user", "ftp-method", "ftp-port", "ftp-ssl-ccc-mode", "happy-eyeballs-timeout-ms",
        "haproxy-clientip", "hostpubmd5", "hostpubsha256", "hsts", "interface", "ip-tos", "ipfs-gateway", "json",
        "keepalive-cnt", "keepalive-time", "key", "key-type", "krb", "libcurl", "limit-rate", "local-port",
        "login-options", "mail-auth", "mail-from", "mail-rcpt", "max-filesize", "max-redirs", "max-time", "netrc-file",
        "noproxy", "oauth2-bearer", "output", "output-dir", "parallel-max", "pass", "pinnedpubkey", "preproxy", "proto",
        "proto-default", "proto-redir", "proxy", "proxy-cacert", "proxy-capath", "proxy-cert", "proxy-cert-type",
        "proxy-ciphers", "proxy-crlfile", "proxy-header", "proxy-key", "proxy-key-type", "proxy-pass",
        "proxy-pinnedpubkey", "proxy-service-name", "proxy-tls13-ciphers", "proxy-tlsauthtype", "proxy-tlspassword",
        "proxy-tlsuser", "proxy-user", "proxy1.0", "pubkey", "quote", "random-file", "range", "rate", "request-target",
        "resolve", "retry", "retry-delay", "retry-max-time", "sasl-authzid", "service-name", "sigalgs", "socks4",
        "socks4a", "socks5", "socks5-gssapi-service", "socks5-hostname", "speed-limit", "speed-time", "stderr",
        "telnet-option", "tftp-blksize", "time-cond", "tls-max", "tls13-ciphers", "tlsauthtype", "tlspassword",
        "tlsuser", "trace", "trace-ascii", "trace-config", "unix-socket", "upload-file", "url-query", "variable",
        "vlan-priority", "write-out"
    ]

    static func takesValue(short name: Character) -> Bool {
        shortNamesTakingValues.contains(name)
    }

    /// `--expand-x` is curl's `--x` with its value's `{{variables}}` expanded.
    static func takesValue(long name: String) -> Bool {
        let baseName = name.trimmingPrefix("expand-")
        return longNamesTakingValues.contains(String(baseName)) || CurlOption(long: String(baseName))?
            .takesValue == true
    }

}
