//  TaskMetricsRecorder.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import Synchronization

final class TaskMetricsRecorder: NSObject, URLSessionTaskDelegate {

    private let recorded = Mutex<HTTPMetrics?>(nil)
    private let cookies: CookieExchange?

    init(cookies: CookieExchange? = nil) {
        self.cookies = cookies
    }

    var metrics: HTTPMetrics? {
        recorded.withLock { $0 }
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let mapped = HTTPMetrics(recorded: RecordedTaskMetrics(metrics))
        recorded.withLock { $0 = mapped }
    }

    /// The only place a redirect response's cookies can be read. The new request carries the old `Cookie` header,
    /// so it is worked out again for the new URL, and jar cookies never reach another host. Not the `async` form:
    /// Swift 6.4.2's compiler crashes emitting its Objective-C thunk.
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let cookies else {
            completionHandler(request)
            return
        }
        Task {
            await cookies.receive(response)
            await completionHandler(cookies.preparing(request))
        }
    }

}
