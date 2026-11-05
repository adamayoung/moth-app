//  AppDependencies.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import HTTPKit
import MothCore

protocol AppDependencies: AnyObject {

    var transport: any HTTPTransport { get }

    var secretStore: any SecretStore { get }

    var iCloudContainerIdentifier: String? { get }

}
