# Architecture

## System Overview

Moth is a macOS SwiftUI API client. It stores workspaces, collections and
environments in SwiftData, syncs them through the user's private CloudKit
database, keeps secrets in the Keychain, and sends requests through URLSession.
`MothApp` chooses a dependency graph and then delegates to `MacScene`.

```text
SwiftUI views -> AppModel commands -> service protocols -> HTTPKit
      |                                      |
      +----------- SwiftData @Query <--------+-- mappers + ModelContext
```

Views read persisted data directly with `@Query`. `AppModel` coordinates
commands and app-wide state; it is not a repository for view data.

## Stack

These are decided. Do not reopen them without being asked.

- Swift 6 with strict concurrency, SwiftUI, SwiftData, and CloudKit sync through
  the private database.
- macOS first, minimum 27.2, with iOS and iPadOS kept feasible for later: no
  AppKit in any package.
- URLSession behind an `HTTPTransport` protocol, not SwiftNIO. URLSession gives
  us HTTP/1.1, 2 and 3, TLS, proxies, cookies, streaming and
  `URLSessionTaskMetrics`. Swap to async-http-client only for a real wall, such
  as raw or malformed requests or raw wire bytes.
- Secrets in the Keychain with `kSecAttrSynchronizable`, never in SwiftData.
- Licence: MIT.

## Module Boundaries

| Module | Responsibility | Depends on | Default isolation |
| --- | --- | --- | --- |
| `Moth` | Scene roots, SwiftUI, commands, `AppModel`, dependency composition, and platform-only APIs | `MothCore`, `MothImport`, `HTTPKit` | `MainActor` |
| `MothImport` | Mapping Postman collections and environments to and from the domain, cURL import, and code generation (cURL, Swift URLSession) | `MothCore`, `PostmanKit` | `MainActor` |
| `MothCore` | Domain types, variable resolution, auth providers, SwiftData models and schemas, CloudKit configuration, the Keychain secret store, mappers, and services | `HTTPKit` | `MainActor` |
| `HTTPKit` | `HTTPTransport`, its URLSession implementation, metrics capture, the redirect chain, and the cookie jar; no SwiftData or UI | nothing | `nonisolated` |
| `PostmanKit` | Codable wire models for Postman Collection v2.1 and Environment JSON; no SwiftData or UI | nothing | `nonisolated` |

Non-UI modules have no SwiftUI or AppKit dependency and are fully unit-testable.
Every package declares iOS as well as macOS, and CI builds them for iOS, so an
AppKit import fails.

Wire models stay in the kits and are mapped into `MothCore`. Keep AppKit,
SwiftUI presentation and application lifecycle code in the app target. Add
reusable domain behaviour below the view layer rather than teaching views about
transport or persistence.

`MothCore` sits above `HTTPKit`, not below it: a kit knows nothing about the
domain. `HTTPKit` takes a `URLRequest`, and `MothCore` builds that request from
a resolved domain request.

A folder in a target's membership compiles what it can and copies every other
file into the app bundle. Keep `Packages/`, `TestPlans/` and `Configs/` out of
the app target's membership, and read the built bundle's `Contents/Resources`
before the first distribution build.

## Composition and Launch Modes

`AppDependencies` is the composition contract. `DependencyProvider` selects a
long-lived graph for the current `AppLaunchMode`:

- live launches use the persistent stores, CloudKit, the real transport and the
  Keychain, or an in-memory secret store when the build is ad hoc
  ([Secrets](#secrets) says why);
- UI-test and demo launches use seeded data, in-memory stores and an in-memory
  secret store;
- the test host that app-hosted unit tests run in opens no windows, and its
  graph is an empty seeded one. `MothAppLauncher` picks a separate `App` for it.

Dependencies are stored once by `LiveAppDependencies` or
`SeededAppDependencies`. Do not turn them into computed factories: services,
model containers and stores must share identity for the lifetime of the process.
Consume services through their protocols so tests and previews can substitute
focused doubles. This is plain constructor injection at one composition root,
with no container.

Anything the app does with no window open belongs to an owner that lives as
long as the app, never to a `.task` on a view.

`LiveAppDependencies` takes the function that opens its store, and that function
has no default, so a test cannot reach the real store or CloudKit by leaving it
out. A bad launch argument stops the launch through `stopLaunch`, which logs and
prints the reason and exits, because `fatalError` would leave a crash dialog on
screen.

A live store that will not open gives `LaunchOutcome.storeFailure`, and
`MothAppLauncher` starts `StoreFailureApp` in place of `MothApp`. It opens no
window and shows an alert whose only button is Quit. Moth never offers to delete
the store, because synced data is at stake. A seeded store that will not open
still stops the launch, so that a test host cannot wait on an alert.

## Domain Model

Postman-shaped:

- A **Workspace** holds **Collections** and **Environments**, plus **Globals**
  and its active environment.
- A **Collection** is a tree of **Folders** and **Requests**.
- An **Environment** holds **Variables**, each with an initial value, a current
  value, an enabled flag and `isSecret`.
- A **Request** has a name, method and URL template; query and path parameters;
  headers with a per-row enabled flag; a body; auth; and settings.
- A **Body** is none, form-data, urlencoded, raw with a content type, binary or
  GraphQL.
- **Auth** is inherited, or overridden with none, Basic, Bearer, API key, Digest,
  OAuth2 or AWS SigV4.
- **Settings** cover redirects, timeout and SSL verification.
- A **HistoryEntry** records a sent request and its response.

### Variables

`{{name}}` resolves request, then collection, then environment, then globals.
Dynamic variables are `{{$guid}}`, `{{$timestamp}}` and `{{$randomInt}}`.

A value can hold further references, up to ten variables in a chain, and one
resolution has a size budget, because depth alone allows billions of expansions
from one imported file. A reference that is undefined, part of a cycle, too deep,
over budget or a missing secret stays as written and is reported.

`VariableResolver` returns a `ResolvedRequest`. It holds plaintext secrets, so it
is not a `Request` and nothing that persists a request can take one. Its `auth`
keeps its references, and `credentials` holds their values, expanded, because an
import stores a credential as written and that is often `{{token}}`.

### Auth

An auth provider is a protocol that mutates a `URLRequest`. Its requirement must
be `async throws`: OAuth2 refreshes tokens, and SigV4 has to sign the final
body. Digest answers a 401 challenge, so it also needs the transport to retry.

`.inherit` is replaced before resolution, by `RequestCollection.effectiveAuth(of:)`,
because `VariableResolver` fetches secrets only for the auth it is given. The walk
goes up through folders to the collection and stops at the first that sets auth,
where setting `.none` counts. A request outside the tree inherits nothing, so a
credential cannot reach it by accident.

`RequestBuilder` turns a `ResolvedRequest` into the `URLRequest` that `HTTPKit`
sends. An invalid URL or method, or a Bearer token a header cannot hold, throws.
What it cannot send stays out of the request and is reported in
`BuiltRequest.notices`: an auth kind with no provider, a binary or GraphQL body, a
form-data file field, a header URLSession would drop or alter, and a body on GET
or HEAD. A credential with no stored value sends no auth, and
`ResolvedRequest.unresolvedCredentials` already reports it. An auth provider's
`Authorization` header replaces a manual one. `URLRequest` holds one value per
header name, so repeated names go out comma-joined, and repeated cookies joined by
`; `.

### Postman Import

`PostmanImporter` takes a file's bytes, so the app needs no `PostmanKit` type, and
returns domain values with counts of what it imported and skipped. It writes
nothing to the store. Secrets are saved once mapping finishes, and a failed save
removes those already saved. A caller whose store write then fails removes
`PostmanImportResult.secrets`.

Moth keeps what it can store and counts the rest:

- A query that has rows leaves the URL template, because `RequestBuilder` appends
  rows to a template's own query and would send it twice. Query rows and path
  variables are stored percent-decoded, because `RequestBuilder` encodes them.
- A credential goes to the secret store as written. An empty one saves nothing, so
  it is reported as missing. Basic and Digest always save a password, because they
  can send a username alone.
- API key, AWS, Digest and OAuth2 are stored by kind and counted as unsupported
  until they have a provider.
- OAuth 1.0, Hawk, NTLM, EdgeGrid and unknown types become `.none` and lose their
  credentials. `.none` stops the walk up the tree, so a parent's credential cannot
  reach something that asked for another scheme.
- Scripts with code, folder variables, descriptions, saved example responses and
  unknown body modes are dropped and counted.

`PostmanKit` does not decode `protocolProfileBehavior`, so a request's settings
stay at Moth's defaults, and nothing counts that.

## Persistence

### Two Stores

The container holds two `ModelConfiguration`s:

- a **synced store**, using `cloudKitDatabase: .private(<container>)`, for
  workspaces, collections, requests and environments;
- a **local store**, using `cloudKitDatabase: .none`, for response bodies and
  history snapshots, which get big and are not synced.

A model belongs to exactly one store. `HistoryEntry` refers to its request by
identifier, not by `@Relationship`.

`DataModel` owns both stores, and `StoreConfigurations` builds them. A container
identifier selects `.private`, and no identifier selects `.none`. Each store has
its own file in the directory `DataModel` is given. `LiveAppDependencies` passes
the container only if the running app is entitled to it, so an unsigned build
stays off CloudKit whatever its Info.plist says. `isSyncedToICloud` reports that
same result, and the sidebar's "iCloud Sync Off" footer follows it.

### Rows and Stored JSON

Each workspace, collection, folder, request, environment and variable is a row,
so two Macs changing different rows keep both changes. A variable is one model
with an owner relationship for each scope.

A request's parameters, headers, body, auth and settings, and a collection's or
folder's auth, are JSON in `Data` attributes, encoded by `StoredJSON` with sorted
keys. Two Macs changing one of these on the same row can overwrite each other.
That JSON is part of the frozen schema, and `StoredJSONTests` pins it. A secret is
stored as its reference. Stored JSON a build cannot read throws, because a
default would hide the value and the next save would overwrite it.

### The Implicit Workspace

There is one workspace, with no switcher. No launch creates it: the first
collection or environment does, so a fresh install on two Macs seeds nothing to
duplicate.

Two Macs can still each create one. `StoreWriter` reconciles after every write
batch, in that batch's save, and `LiveAppDependencies` reconciles at launch. The
lowest `id` survives, because every Mac makes that choice alone and they must
agree. Every collection, environment and global not already on the survivor
moves to it, and the other workspaces are deleted.

A workspace's relationships nullify rather than cascade. A merge's delete reaches
other Macs, where a cascade would delete a child that has not synced yet. A
nullified child is an orphan, and reconcile adopts it. `VariableModel.isGlobal`
tells an orphaned global from a variable whose owner has not been imported yet,
which reconcile leaves alone.

### CloudKit Model Rules

Every model in the synced store follows these from its first version. Apple's
[Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
gives the reasons.

- All relationships are optional, and every relationship sets its inverse.
- No `@Attribute(.unique)`. Duplicates can arrive through sync, so services
  deduplicate by identifier.
- No `.deny` delete rule.
- Every stored property has a default.
- Ordering uses an explicit `sortOrder` field.

### Schema Versioning

Every model belongs to a `VersionedSchema` from `SchemaV1`, under a migration
plan. A schema version on `main` is frozen. CloudKit adds a stricter limit:
once promoted to production, a schema is additive only, so a model type cannot
be deleted and an existing attribute cannot be changed. Promote the development
schema before release.

### Stores From Another Schema

Before either store opens, `StoreSchemaCheck` compares each store file's entity
version hashes with the schemas in `MothMigrationPlan.schemas`. A store with an
entity or a hash that no planned version has stops the launch, neither store
opens, and the store failure alert says the data came from a newer version of
Moth. SwiftData does this itself only once the plan has a stage, and until then
it opens such a store with no error and drops the columns it does not know.

The check reads a copy of the store's files, so a refused store keeps every byte.
It compares hashes, not `NSStoreModelVersionIdentifiers`, and it allows a store to
hold fewer entities than the schema, because `CloudKitSchemaInitialiser` makes a
store of the synced models only. So a newer schema that only removes models
passes. An empty file is left to SwiftData, which starts a new store over it, and
any other file the check cannot read stops the launch, with no claim about why.

Hashes cover the schema's shape. They do not see the JSON in a `Data` attribute, so
a newer build that adds a key to that JSON passes the check, and an older build
drops the key the next time it writes that value.

A hash that drifts refuses a good store: if an OS update changed how SwiftData
derives hashes, a shipped build would refuse the stores it wrote. That fails safe,
because the data stays intact and an update of Moth can accept the old hashes, where
a false pass loses data for good. Pinned hashes catch this on a new SDK.

The check guards the files on this Mac. A newer Mac's changes reach an older one
through CloudKit, which leaves the older Mac's file on its own schema, so no check
of the file can see them. See [Open Questions](#open-questions).

### Writing to the Store

A SwiftData save writes back the whole row as its context last read it, and
SwiftData has no merge policy, so two contexts saving one row out of step revert
each other's change. The save does not fail: a stale context that changes one
property puts the row's other properties back to the values it read, and `save()`
returns normally.

A `FetchDescriptor` fetch prevents this: it brings a row up to date even in a
long-lived context that still holds an instance of the row. Two things defeat it.
`ModelContext.model(for:)` returns the held instance without refreshing it, so it
never stands in for a fetch. A fetch also leaves a row with unsaved changes as it
was, so a context with pending changes reverts other writers on its next save.

So `StoreActor` can keep one context and needs no new one per write. Every write
runs on `StoreActor` or through `StoreWriter`: fetch rows by identifier with a
`FetchDescriptor` immediately before changing them, save in one synchronous step,
and call `rollback()` if the save throws, which clears the pending changes so the
next fetch refreshes the row. The main context reads only, with autosave off. An
editor edits a value-type draft and commits it through the writer.

A view reads flat `@Query` results, not a row's to-many arrays, which go stale on
the main context once the writer saves. `CollectionTree` builds the sidebar's
value tree from those rows, and selection names a row by identifier, so a sync
that removes a row moves the selection to the nearest surviving ancestor.

Models are `public` for `@Query`, but only `MothCore` can make one or set a
property, and `StoreWriter`'s commands take domain values. `WriteBoundaryTests`
holds this. It covers `MothCore`'s surface: anyone holding a context can still
call SwiftData's own `delete` and `save`.

A seed is the one write outside `StoreWriter`. `DataModel.inMemory(seed:)` writes
it into a new in-memory store before any reader exists, so a seeded launch has its
data at the first frame.

## Secrets

Secret variables, auth credentials and tokens live in the Keychain with
`kSecAttrSynchronizable`. SwiftData holds only a reference: an identifier of our
own, never a Keychain persistent reference, which Apple says not to use for
synchronizable items.

[`kSecAttrSynchronizable`](https://developer.apple.com/documentation/security/ksecattrsynchronizable)
sets these conditions:

- Accessibility must not be a `ThisDeviceOnly` value.
- Updating or deleting an item affects every device's copy.
- Items behave like iOS keychain items, so they need a signed app.

A reference can sync before its secret does, or the user may have iCloud
Keychain turned off. A missing secret is a normal state the UI must handle.

### Which Store a Build Uses

`AppSignature` reads the running app's own signature, and `LiveAppDependencies`
chooses from it, so the entitlement decides and a build setting cannot disagree:

| Build | Secret store |
| --- | --- |
| Ad hoc or unsigned | `InMemorySecretStore`, so secrets last until quit |
| Team-signed, no iCloud container | `KeychainSecretStore` in `.localOnly` mode, on the login keychain |
| Team-signed, iCloud container | `KeychainSecretStore` in `.synchronised` mode, under the app's access group |

Moth never causes a Keychain password prompt, and that decides the first row. An
ad hoc build's designated requirement is its cdhash, so a rebuilt binary is a
different app to an item's access list, and reading an item an earlier build
saved prompts for a password. `kSecUseAuthenticationUI` and
`LAContext.interactionNotAllowed` do not stop that prompt on the login keychain.
The data protection keychain returns `errSecMissingEntitlement` to an ad hoc
build, and signing one with `keychain-access-groups` gets it killed at launch.

Only the iCloud entitlements carry `keychain-access-groups`, so a team-signed
build with no container uses the login keychain. Its identity is stable, so a
rebuild reads and replaces an item with no prompt. Removing an item an earlier
build saved fails with `errSecInvalidOwnerEdit`, and reports that as an error.
The service name holds the team, so one team's build never queries another's
items, which would prompt.

## Configs and Signing

`Configs/Debug.xcconfig` and `Configs/Release.xcconfig` set warnings as errors.
Each ends with `#include? "Local.xcconfig"`, a gitignored file where a contributor
sets their own team. The iCloud container comes from a build setting. A build
without one, or without its entitlement, runs on `cloudKitDatabase: .none`, so a
contributor can build Moth without the owner's signing identity. Local builds sign, ad hoc until a team is
set, and an ad hoc build keeps secrets in memory. CI builds with `CODE_SIGNING_ALLOWED=NO`, which has neither iCloud nor
Keychain entitlements, so it uses `.none` stores and an in-memory secret store.

The app is sandboxed with outgoing network connections allowed. It carries an
App Transport Security exception because an API client has to reach plain-HTTP
hosts, and localhost above all.

## Transport

`HTTPTransport.send` returns the final response, and `HTTPResponse.metrics`
describes it. Phases and bytes come from the last of a task's transactions,
because that one carries the final response. `totalTime` and `redirectCount`
cover the whole task.

The phases run end to end: `dns`, `connect`, `tls`, `firstByte` and `download`.
`connect` stops where the TLS handshake starts, because URLSession's connect end
date includes it. Over QUIC, which handshakes as it connects, `connect` is close
to zero and `tls` holds the handshake. `firstByte` starts with the request, so it
includes any upload. A phase that did not happen, such as on a reused connection,
is `nil`.
`bytesReceived` counts the final response's header and body bytes on the wire.

`metrics` is optional because URLSession does not say when it delivers them
relative to `data(for:delegate:)` returning. They arrived first in every send
measured, but `send` reads what has arrived and never waits. A stub transport has
none.

`HTTPTransportError.translating` is the only code that decodes a `URLError`, so
the app never does. A timeout, a connection failure, a TLS failure and anything
else are separate cases, and each keeps the system's description. A cancelled
send throws `CancellationError`, which is not a failure.

URLSession merges a repeated response header into one comma-separated value,
`Set-Cookie` included. `URLSessionLoopbackTests` records this. Keeping them apart
needs the transport swap that [Stack](#stack) reserves for a real wall.

## Concurrency

`MothCore`, `MothImport` and the app default to `MainActor`. `HTTPKit` and
`PostmanKit` do not, because they exist to run off it. Values that cross into
`HTTPKit` are `Sendable` value types, never a `@Model`.

A closure passed to an Objective-C API from `MainActor`-default code is inferred
`@MainActor`, and traps if the framework calls it on its own queue. Write
`@Sendable` on every such completion handler, and `nonisolated` on delegate
methods.

## Privacy

The app includes no analytics, crash-reporting or feature-flag service. Its only
network traffic is the requests the user sends and iCloud sync. It never writes
outside its own container, and never touches another tool's configuration.

## Open Questions

Settle each with a test before the code that depends on it.
`SwiftDataCrossStoreCharacterisationTests`,
`SwiftDataStaleSaveCharacterisationTests` and
`SwiftDataNewerStoreCharacterisationTests` in `MothCoreTests` hold the tests behind
the settled answers, and fail if an OS or SDK update changes them.

- **Cross-store relationships: settled.** A relationship cannot cross the two
  stores. A configuration's schema takes in every model its models relate to, so
  two related models belong to both configurations, and SwiftData puts both rows
  in one store with no error. Which store varied between containers opened with
  the same configurations, so a relationship from a local model to a synced one
  could put local rows in the synced store. Relating rows that are already in
  different stores is a fatal error at the assignment, before any save, and no
  `catch` can handle it. These tests use `cloudKitDatabase: .none` stores.
- **A second context as a second writer: settled.** A stale save reverts the other
  context's change, as [Writing to the Store](#writing-to-the-store) describes.
  This holds for a second `ModelContext` on one container, in memory and on disk.
- **Opening a store from a newer schema: settled for the store files.** While
  `MothMigrationPlan.stages` is empty, SwiftData opens such a store with no error,
  keeps its rows and drops the columns this build does not know. With a stage in
  the plan, SwiftData refuses the store and leaves it intact. `StoreSchemaCheck`
  refuses it in either case, as
  [Stores From Another Schema](#stores-from-another-schema) describes, and its
  tests pin `SchemaV1`'s entity hashes, because an OS or SDK update that changed
  them would refuse every existing store. Setting up CloudKit mirroring adds no
  entity to those hashes, but no test covers a store that has synced with a real
  iCloud account, so that needs a manual check before release.
- **A newer Mac's records reaching an older Mac: unverified.** They arrive through
  CloudKit, not the store file. The additive-only rule suggests the older Mac
  ignores what it does not know and its own saves leave those fields alone, but
  no test covers this. It needs a check on two Macs with two schema versions.
- **CloudKit as a second writer: unverified.** Sync imports write outside
  `StoreActor`, and the tests above use no iCloud account, so they show the
  mechanism and not what an import does. Whether a stale context's save can revert
  an imported change, and whether an import can land between a writer's fetch and
  its save, stay unknown until the manual two-Mac check in
  [#20](https://github.com/adamayoung/moth-app/issues/20). They decide whether the
  writer rule is enough.
