//  RequestTabStore.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation

/// `UserDefaults` rather than `@SceneStorage`, because UI tests launch with saved state ignored. Defaults never sync.
struct RequestTabStore {

    /// Empty on every use, because previews share one process and one would otherwise show another's tabs.
    static var preview: RequestTabStore {
        let store = RequestTabStore(defaults: .standard, key: "PreviewRequestTabs")
        store.clear()
        return store
    }

    let defaults: UserDefaults
    let key: String

    /// Unreadable data loads as no tabs, because this is window state and nothing of the user's is lost.
    func load() -> RequestTabs {
        guard let data = defaults.data(forKey: key),
              let tabs = try? JSONDecoder().decode(RequestTabs.self, from: data)
        else {
            return RequestTabs()
        }
        return tabs
    }

    func save(_ tabs: RequestTabs) {
        guard let data = try? JSONEncoder().encode(tabs) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

}
