//  AppDependencies.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import HTTPKit
import MothCore

protocol AppDependencies: AnyObject {

    var transport: any HTTPTransport { get }

    var secretStore: any SecretStore { get }

    var dataModel: DataModel { get }

    var requestTabStore: RequestTabStore { get }

    var requestDrafts: RequestDrafts { get }

    var iCloudContainerIdentifier: String? { get }

    var isSyncedToICloud: Bool { get }

    var activeEnvironment: ActiveEnvironment { get }

    var importFileSource: ImportFileSource { get }

    var clipboard: Clipboard { get }

}
