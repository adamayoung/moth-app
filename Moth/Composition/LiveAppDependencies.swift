//  LiveAppDependencies.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import MothCore
import OSLog

final class LiveAppDependencies: AppDependencies {

    let transport: any HTTPTransport = URLSessionHTTPTransport(session: makeSession())
    let secretStore: any SecretStore
    let dataModel: DataModel
    let iCloudContainerIdentifier: String?
    let isSyncedToICloud: Bool
    let activeEnvironment = ActiveEnvironment(defaults: .standard)
    let launchReconcile: Task<Void, Never>

    /// `openDataModel` has no default, so that no test can reach the real store or CloudKit by leaving it out.
    init(
        infoDictionary: [String: Any],
        signature: AppSignature,
        openDataModel: (_ containerIdentifier: String?) throws -> DataModel
    ) throws {
        let configuredIdentifier = infoDictionary["MothICloudContainer"] as? String ?? ""
        let identifier = configuredIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let containerIdentifier = identifier.isEmpty ? nil : identifier
        let syncedContainer = Self.syncedContainer(containerIdentifier, signature: signature)
        let dataModel = try openDataModel(syncedContainer)
        self.iCloudContainerIdentifier = containerIdentifier
        self.isSyncedToICloud = syncedContainer != nil
        self.secretStore = Self.makeSecretStore(signature: signature)
        self.dataModel = dataModel
        self.launchReconcile = Self.reconcileAtLaunch(dataModel.writer)
    }

    /// The entitlement decides, as for the secret store: an unsigned build still has the setting in its Info.plist.
    private static func syncedContainer(_ identifier: String?, signature: AppSignature) -> String? {
        guard let identifier, signature.iCloudContainers.contains(identifier) else {
            return nil
        }

        return identifier
    }

    /// Lives on the graph, not a view's `.task`, because it must run with no window open. A failure is logged and
    /// not fatal: the next write reconciles again.
    private static func reconcileAtLaunch(_ writer: StoreWriter) -> Task<Void, Never> {
        Task {
            do {
                try await writer.reconcileWorkspaces()
            } catch {
                Logger.composition.error(
                    "Reconciling workspaces at launch failed: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    /// An ad hoc build is a new app to the Keychain after every rebuild, so reading a saved item would prompt.
    /// Reading another team's item would prompt too, so the team is part of the service name.
    private static func makeSecretStore(signature: AppSignature) -> any SecretStore {
        guard let teamIdentifier = signature.teamIdentifier else {
            return InMemorySecretStore()
        }
        let service = "uk.co.adam-young.Moth.secrets.\(teamIdentifier)"
        if let accessGroup = signature.keychainAccessGroup {
            return KeychainSecretStore(service: service, mode: .synchronised(accessGroup: accessGroup))
        }
        return KeychainSecretStore(service: service, mode: .localOnly)
    }

    /// An API client shows what the server sent, so no cached response, cookie or credential carries between requests.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration)
    }

}
