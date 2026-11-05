//  SchemaFixtures.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

/// Same entity names in each namespace, so that a fingerprint differs only by the change each one seeds.
enum BaselineFixture {

    @Model
    final class Owner {
        var name = ""

        @Relationship(deleteRule: .cascade, inverse: \Item.owner)
        var items: [Item]? = []

        init() {}
    }

    @Model
    final class Item {
        var owner: Owner?

        init() {}
    }

}

enum AddedAttributeFixture {

    @Model
    final class Owner {
        var name = ""
        var addedAfterTheFreeze = ""

        @Relationship(deleteRule: .cascade, inverse: \Item.owner)
        var items: [Item]? = []

        init() {}
    }

    @Model
    final class Item {
        var owner: Owner?

        init() {}
    }

}

enum ChangedDeleteRuleFixture {

    @Model
    final class Owner {
        var name = ""

        @Relationship(deleteRule: .nullify, inverse: \Item.owner)
        var items: [Item]? = []

        init() {}
    }

    @Model
    final class Item {
        var owner: Owner?

        init() {}
    }

}

/// Breaks every CloudKit rule, to show that an empty list of violations means something.
enum CloudKitViolationsFixture {

    @Model
    final class Owner {
        @Attribute(.unique)
        var code = ""

        var requiredWithNoDefault: String

        @Relationship(deleteRule: .deny)
        var items: [Item]? = []

        var required: Item

        init(requiredWithNoDefault: String, required: Item) {
            self.requiredWithNoDefault = requiredWithNoDefault
            self.required = required
        }
    }

    @Model
    final class Item {
        init() {}
    }

}
