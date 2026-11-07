//  SendTaskDelegate.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import Synchronization

final class SendTaskDelegate: NSObject, URLSessionTaskDelegate {

    private let recorded = Mutex<HTTPMetrics?>(nil)
    private let hasLeftOrigin = Mutex(false)
    private let cookies: CookieExchange?
    private let policy: SendPolicy
    private let origin: URL?

    init(cookies: CookieExchange? = nil, policy: SendPolicy = SendPolicy(), origin: URL? = nil) {
        self.cookies = cookies
        self.policy = policy
        self.origin = origin
    }

    var metrics: HTTPMetrics? {
        recorded.withLock { $0 }
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let mapped = HTTPMetrics(recorded: RecordedTaskMetrics(metrics))
        recorded.withLock { $0 = mapped }
    }

    /// Answering `nil` makes URLSession return the redirect response itself. Credentials that leave the origin don't
    /// come back to it later in the chain. The only place a redirect response's cookies can be read, so the jar's
    /// `Cookie` header is worked out again for the new URL. Not the `async` form: Swift 6.4.2's compiler crashes
    /// emitting its Objective-C thunk.
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard policy.followsRedirects else {
            completionHandler(nil)
            return
        }
        let isAway = hasLeftOrigin.withLock { hasLeft in
            hasLeft = hasLeft || request.url?.hasSameOrigin(as: origin) != true
            return hasLeft
        }
        let request = isAway ? withoutCredentials(request) : request
        guard let cookies else {
            completionHandler(request)
            return
        }
        Task {
            await cookies.receive(response)
            await completionHandler(cookies.preparing(request, withManualHeader: !isAway))
        }
    }

    /// Only an unverified send's session reaches this with a server trust to accept, because the verified session
    /// never shares its connections with it.
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let space = challenge.protectionSpace
        guard
            !policy.verifiesTLS,
            space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = space.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private func withoutCredentials(_ request: URLRequest) -> URLRequest {
        var request = request
        for name in policy.credentialHeaders {
            request.setValue(nil, forHTTPHeaderField: name)
        }
        return request
    }

}
