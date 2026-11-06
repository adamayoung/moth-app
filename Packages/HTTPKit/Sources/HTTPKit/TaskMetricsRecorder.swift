//  TaskMetricsRecorder.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import Synchronization

final class TaskMetricsRecorder: NSObject, URLSessionTaskDelegate {

    private let recorded = Mutex<HTTPMetrics?>(nil)

    var metrics: HTTPMetrics? {
        recorded.withLock { $0 }
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let mapped = HTTPMetrics(recorded: RecordedTaskMetrics(metrics))
        recorded.withLock { $0 = mapped }
    }

}
