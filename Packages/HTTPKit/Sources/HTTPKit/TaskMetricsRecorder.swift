//  TaskMetricsRecorder.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import Synchronization

final class TaskMetricsRecorder: NSObject, URLSessionTaskDelegate {

    private let recorded = Mutex<RecordedTaskMetrics?>(nil)

    var metrics: HTTPMetrics? {
        recorded.withLock { $0 }.map(HTTPMetrics.init(recorded:))
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let mapped = RecordedTaskMetrics(metrics)
        recorded.withLock { $0 = mapped }
    }

}
