//  FormDataField+Sending.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated extension FormDataField {

    var isSent: Bool {
        isEnabled && !key.isEmpty
    }

}
