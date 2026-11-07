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
  us HTTP/1.1, 2 and 3, TLS, proxies, streaming and
  `URLSessionTaskMetrics`. Swap to async-http-client only for a real wall, such
  as raw or malformed requests or raw wire bytes.
- Secrets in the Keychain with `kSecAttrSynchronizable`, never in SwiftData.
- Licence: MIT.

## Module Boundaries

| Module | Responsibility | Depends on | Default isolation |
| --- | --- | --- | --- |
| `Moth` | Scene roots, SwiftUI, commands, `AppModel`, dependency composition, and platform-only APIs | `MothCore`, `MothImport`, `HTTPKit` | `MainActor` |
| `MothImport` | Mapping Postman collections and environments to and from the domain, cURL import, and code generation (cURL, Swift URLSession) | `MothCore`, `PostmanKit` | `MainActor` |
| `MothCore` | Domain types, variable resolution, auth providers, SwiftData models and schemas, CloudKit configuration, the Keychain secret store, each workspace's cookie jar, mappers, and services | `HTTPKit` | `MainActor` |
| `HTTPKit` | `HTTPTransport`, its URLSession implementation, metrics capture, the redirect chain, and the cookie rules and jar protocol; no SwiftData or UI | nothing | `nonisolated` |
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
long as the app, never to a `.task` on a view. `MothAppDelegate` asks before a
quit that would lose edits, so it reads `RequestDrafts` from the graph.

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

`RequestBuilder` applies the provider last, so `AWSSigV4AuthProvider` signs the
final URL, headers and body, with the time the send started, which History records
too. `AWSSigV4Signer` works on the wire form of a request, and AWS's published
suite checks it. A required
credential with no value stops the build, unlike Basic and Bearer, because an
unsigned call to AWS would come back as a bare 403. A session token with no value
is left off and noted. Headers URLSession reserves aren't signed, because it can
rewrite them.

`.inherit` is replaced before resolution, by `RequestCollection.effectiveAuth(of:)`,
because `VariableResolver` fetches secrets only for the auth it is given. The walk
goes up through folders to the collection and stops at the first that sets auth,
where setting `.none` counts. A request outside the tree inherits nothing, so a
credential cannot reach it by accident.

`CollectionTree.inheritedAuth(of:)` makes the same walk for the editor's Inherit
message, from each container's `authData`, so it decodes no request body. A
container whose auth can't be read ends that walk, and its Authorization… command
is disabled, because a Save would overwrite what it holds.

`RequestBuilder` turns a `ResolvedRequest` into the `URLRequest` that `HTTPKit`
sends. An invalid URL or method, or a Bearer token or API key a header cannot hold,
throws. What it cannot send stays out of the request and is reported in
`BuiltRequest.notices`: an auth kind with no provider, an API key with no name, a
binary or GraphQL body, a
form-data file field, a header URLSession would drop or alter, a body on GET or
HEAD, a key that resolved to empty, and a path variable with no value. A
credential with no stored value sends no auth, and
`ResolvedRequest.unresolvedCredentials` already reports it. `VariableResolution`
records which part of the request each unresolved variable came from, and
`BuiltRequest.unresolved` leaves out one that only a left-out part held. A key
that resolved to empty is reported as the tab shows it, because it has no resolved
name to show. An auth provider's
`Authorization` header replaces a manual one, and an API key replaces a manual
header or query parameter of its name, including one typed into the URL. `URLRequest` holds one value per
header name, so repeated names go out comma-joined, and repeated cookies joined by
`; `.

### Postman Import

`PostmanImporter` takes a file's bytes, so the app needs no `PostmanKit` type, and
returns domain values with counts of what it imported and skipped. It writes
nothing to the store itself. Secrets are saved once mapping finishes, and a failed
save removes those already saved. `importFile(_:…:into:)` then hands the content to
the store it is given, and removes the import's secrets if that throws. A removal
that fails, or a quit between the two steps, leaves a stray Keychain item, which is
harmless.

File > Import… belongs to `ImportModel`, one per window. It reads the chosen file
inside its security scope, because the sandbox grants user-selected files read-only
and only within that scope. `StoreWriter.create(_:)` writes a whole collection or
environment in one `write` batch, so a failed save leaves nothing of it. Reading,
mapping and saving secrets all run off the main actor, and the store write runs on
`StoreActor`. "Importing…" is a sidebar footer, not a sheet, so the window stays
usable. A result that lands behind another sheet waits for it to close. Closing a
window during an import still finishes the write, and that window's result is lost.

`PostmanImportResult.importedSummary` and `skippedSummary` hold the result sheet's
text, in `MothImport`'s catalog. The skipped list follows the catalog's language
rather than the Mac's region. It names only what was dropped: auth stored by kind
with no provider is not listed, because the send reports it.

Moth keeps what it can store and counts the rest:

- A query that has rows leaves the URL template, because `RequestBuilder` appends
  rows to a template's own query and would send it twice. Query rows and path
  variables are stored percent-decoded, because `RequestBuilder` encodes them.
- A credential goes to the secret store as written. An empty one saves nothing, so
  it is reported as missing. Basic and Digest always save a password, because they
  can send a username alone.
- Digest and OAuth2 are stored by kind and counted as unsupported until they have
  a provider.
- AWS takes Postman's own defaults for a blank region or service, `us-east-1` and
  `execute-api`, so an export that worked there signs here with no edit. An export
  leaves a blank `service` out altogether.
- OAuth 1.0, Hawk, NTLM, EdgeGrid and unknown types become `.none` and lose their
  credentials. `.none` stops the walk up the tree, so a parent's credential cannot
  reach something that asked for another scheme.
- Scripts with code, folder variables, descriptions, saved example responses and
  unknown body modes are dropped and counted.

`PostmanKit` does not decode `protocolProfileBehavior`, so a request's settings
stay at Moth's defaults, and nothing counts that.

### cURL Import

File > Import cURL… opens a sheet on `ImportModel`, and `CurlImporter` turns its
text into one `Request`. Moth reads the command and never runs it. `MothImport`
launches no process, and reads no file the command names.

`ShellWords` reads the text as a shell reads one command, with no expansion, so
`$TOKEN` stays those characters. The command ends where a shell ends it, at an
unquoted newline, `|`, `&` or `;`, and a redirection is set aside, so the words
after it still count. `CurlCommand` walks the words, and
`IgnoredCurlOptions` lists the ignored flags that take a value, because that value
would otherwise read as the URL. `CurlMapper` builds the request, and secrets save
and roll back as a Postman import's do.

- A flag Moth doesn't read, a further URL, a redirection, what follows the command,
  and anything that names a file to read, such as `--data @file`, `-H @file`, `-b file` or
  `-F a=<file`, go in `CurlCommand.ignored`, and the result sheet lists them. With
  nothing ignored, no sheet appears. `-F a=@file` keeps its path in a file row.
- A query leaves the template for rows, as in a [Postman import](#postman-import),
  unless rows can't send it back unchanged, as with `?flag` or `?q=%E9`. Such a
  query stays in the template, and a Save moves it into rows.
  `-d` makes `.urlEncoded` rows if its text is `key=value` pairs under the form
  type, decoded as a query is, because `RequestBuilder` encodes rows. Anything else
  stays `.raw`, under the command's `Content-Type` or the form type curl would send.
- A credential from `-u`, a URL's user and password, or an `Authorization: Basic`
  or `Bearer` header goes to the secret store. A header wins, then `-u`, then the
  URL, as in curl. A second credential header is dropped, because an auth provider
  replaces a manual one. A Basic value that won't decode, and any other scheme,
  stays a plain header, so that secret stays in the row, and the request's auth is
  `.none`, or inherited auth would replace the header. A command that names another
  scheme, such as `--digest` or `--aws-sigv4`, imports no `-u` or URL credential and
  has `.none`, because Basic would send the secret as it stands.
- `followsRedirects` is true only with `-L`, because curl doesn't follow redirects,
  and `verifiesTLS` is false only with `-k`. Sending doesn't read either setting
  yet.
- `.inherit` is the auth of a command with no credential, as for New Request.
- With `-F`, a `Content-Type` header leaves the rows, because curl adds its boundary
  to that header and `RequestBuilder` can't.

The destination is New Request's, `SidebarModel.newRequestContainer`, which falls
back to the first collection with nothing selected. A store write that fails keeps the
sheet open, so the pasted text isn't lost.

## Persistence

### Two Stores

The container holds two `ModelConfiguration`s:

- a **synced store**, using `cloudKitDatabase: .private(<container>)`, for
  workspaces, collections, requests and environments;
- a **local store**, using `cloudKitDatabase: .none`, for response bodies and
  history snapshots, which get big and are not synced, and cookies, which belong
  to one Mac.

A model belongs to exactly one store. `HistoryEntry` refers to its request, and
`CookieModel` to its workspace, by identifier, not by `@Relationship`.

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
collection, environment or global does, so a fresh install on two Macs seeds
nothing to duplicate.

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

### The Active Environment

The active environment belongs to the Mac, not the workspace, so two Macs can
point at different environments. `ActiveEnvironment` keeps it in `UserDefaults`,
and a seeded launch keeps it in memory, because a seeded launch shares the real
app's defaults. `Workspace.activeEnvironmentID` stays in `SchemaV1`, which is
frozen, and the picker does not read it. A seeded launch takes its first value
from there.

It clears when its environment leaves the list, which covers a delete from
another Mac. A launch's first list can't clear it, because that row may not have
synced yet. Until the row arrives, the picker shows No Environment.

### Editing Variables

An environment, Globals and a collection share one sheet. Requests are saved
explicitly, but a sheet has no tab to show an edited state, so a variable saves
as each field commits: on Return, when focus leaves the field, on a toggle, and
when the sheet closes. `VariableTableModel` holds value drafts, and a delivery
from `@Query` replaces a draft only if it has not run ahead of the store. So a
sync can't take text from under someone typing, and the commit that follows
overwrites what arrived. The exception is a change between plain and secret: the
draft takes the store's value and keeps only its name and Enabled, because
committing the old kind would lose a value another Mac has already moved. A
sync can also land before its delivery, so `updateVariable` takes the secret
its caller read and refuses the write if the store has moved on. The model runs
its writes one at a time, because Keychain calls finish in no set order.

### Editing a Request

A request saves explicitly, unlike a variable. An edit changes a `RequestDraft`,
a value type, and File > Save writes its `RequestEdit` through
`StoreWriter.updateRequest`. `RequestEdit` holds the method, URL template, query
and path rows, headers, body and auth. It has no name, so a Save can't undo a
rename from the sidebar.

The URL field shows the query the store keeps in rows, because
[a query that has rows leaves the template](#postman-import). `RequestDraft`
composes the field from the rows that are sent, so a disabled row or one with no
key stays out of it, and a `{{variable}}` stays literal while everything else is
percent-encoded. Typing in the field keeps the text as typed and parses it back
into rows by text, because `{{host}}/users` is no URL until it is resolved. The
enabled rows take the parsed pairs by position, so they keep their identities. A
`+` in the query reads as the space a server reads, because `RequestBuilder` would
send a row's `+` as `%2B`. Path rows come from the URL by the rule sending uses.
Renaming one segment keeps its row, and removing a segment removes it, down to a
bare `:`. A wider change keeps no value by position. A stored row with no segment
in the template stays hidden and is saved as it was, because a variable can hold
the segment. Save shows the stored form, so `?flag` reads `?flag=`: a `KeyValue`
has no null value, and that is what `RequestBuilder` sends.

Rows can't hold everything a template's own query can, and a Save moves that
query into rows. A whole query in one variable, `?{{query}}`, becomes a key. A
variable that holds encoded text is encoded again. An escape that isn't UTF-8,
`%E9`, stays as literal text and goes out as `%25E9`.

`RequestDrafts` holds a saved form and a draft for each request. There is one for
the app, on `AppDependencies`, because the quit alert has no view in reach. So two
windows on one request share a draft, and the alert counts requests. Drafts stay
in memory. Closing a window keeps them, and the alert still counts them.

`RequestEditorObserver` queries the selected tab's row alone, because decoding
every request on each delivery would read every body. A delivery moves the saved
form under an edited draft and leaves the draft, so a sync never takes what was
typed, Revert goes to what is stored now, and the last Save wins. A clean draft
follows the store. A row that can't be decoded shows a message and no editor, and
refuses Save, because [a default would overwrite the value](#rows-and-stored-json).
A failed Save keeps the draft and leaves its tab open.

`BodyDraft` and `AuthDraft` keep each kind's fields while a draft is open, so
trying another kind loses nothing, and only the chosen kind is saved. What the
editor can't change yet stays as it came and shows Not Supported Yet: a binary or
GraphQL body, a form-data file row, and Digest and OAuth2 auth. Such a body or
auth keeps an entry of its own in the picker, and a Save writes the same
bytes. Choosing another kind and saving replaces it.

A typed credential stays on the `AuthDraft`. `RequestEdit` holds references, so
the text has no route to a row. A changed credential takes a new reference, and a
Save never writes to one a row already holds, so a Save that fails changes nothing
stored. It writes the value, then the row, then removes what the row released, and
a row that can't be written takes the new value with it. `AuthDraft` mints its new
references up front, so a Save tried again writes the same item. Clearing a Token
leaves the new reference with no value, because a header can't send an empty token.
An empty Password is saved, because Basic can send a username alone. `AWSSigV4Draft`
keeps these rules for its three credentials. The Access Key is one of them, in the
Keychain like the others, though its field shows the text. Clearing the optional
Session Token leaves the row with no reference, so its old item is released.
`RequestDrafts` runs Saves and reads one at a time, because Keychain calls finish in
no set order.

`updateRequest` takes the edit the draft started from, and writes a body or auth
only if the draft changed it. That keeps what a sync wrote, including to a tab whose
row isn't being delivered, and keeps the stored bytes, because encoding a decoded
value drops any key this build can't read. A changed auth must match what a row still
holds, or the write is refused. The refused draft stays edited, and the next delivery
moves it to the row's references. `updateRequest` returns the references no other
request, folder or collection holds, and it searches each row's auth JSON as bytes,
so a row this build can't read keeps its items.

While a draft is edited, a body or auth nobody touched follows a delivery, and only
its chosen kind's fields change, so text held for another kind stays. A credential
with no stored value stays editable, with "Not available on this Mac yet" as its
placeholder, because an import saves nothing for an empty credential.

The Authorization… sheet sets a collection's or folder's auth through
`StoreWriter.updateAuth`, under the same rules, when its Save button is pressed. A
failed Save keeps the sheet open and says so.

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

`CurrentSchema` names the version this build opens. `SchemaV2` changes only the
local store: it adds `HistoryEntryModel`'s summary, response and timing
attributes. `SchemaV3` adds `CookieModel` to the local store and changes nothing
else. The plan lists every version with no stage, because a staged migration can't
identify a store that holds only some of a version's models, and each store holds
only its configuration's. SwiftData's automatic lightweight migration adds each
version's changes.

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

### Open Tabs

Open tabs belong to this Mac, so they stay out of both stores. `RequestTabStore`
keeps them in `UserDefaults`, which never syncs. It is not `@SceneStorage`, because
UI tests launch with saved state ignored and could not prove a relaunch.

Tabs hold request identifiers only. A tab reads its name and method from
`CollectionTree`, and `RequestTabsModel` closes any tab whose request has left the
store. It goes by the stored rows, because the tree leaves out a request whose
parent has not synced yet, and that tab returns with its request. A window's first
delivery is the whole store, so the same rule drops a saved tab whose request has
gone.

A seeded launch uses its own key, so a UI test never touches the user's tabs. Each
window loads the saved tabs and saves its own, so with two windows the last write
wins.

Request > Select Next Tab (⌃⇥) and Select Previous Tab (⌃⇧⇥) wrap at the ends and
step over the tabs on show, so a tab waiting for its row is never selected. ⇧⌘]
and ⇧⌘[ do the same from invisible buttons in the window, because a SwiftUI menu
has no hidden item. File > New Request (⌘T) opens the new request in a tab, and with
nothing selected it goes in the first collection.

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

A secret variable has one value. Turning on Secret saves the current value, or
the initial value if current is empty, to the Keychain, and only then writes the
reference, because a reference with no value loses it and a stray item is
harmless. Turning it off writes the value to both columns before removing the
item. A variable whose secret has not reached this Mac shows "Not available on
this Mac yet", and its Secret toggle is disabled, because turning it off would
have no value to keep. A read that fails shows the same message and is logged.
The sheet reads again after each delivery from the store and each time it opens.

Removing a variable, or deleting its environment or collection, removes the
Keychain item unless another variable holds that reference.

Replacing a credential on a request, folder or collection removes its Keychain item
once the row has changed, unless another row's auth holds that reference. Deleting
one leaves the item behind as a stray.

### Cookie Values

A cookie's value is the one exception to `kSecAttrSynchronizable`: a session
belongs to one device, so the value is a device-only item, in
`KeychainSecretStore`'s `.deviceOnly` mode, under a service of its own so removing
cookies can never reach a credential. A build with no iCloud container keeps it on
the login keychain, whose items never sync, and an ad hoc build keeps it in memory,
so its jar works until quit. The local store holds the cookie's metadata and the
identifier of its item, and a row whose item is gone is dropped when the jar loads.

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

### Cookies

URLSession's own cookie storage stays off, so Moth never touches the system's
cookies. A send takes a `CookieJar`, and `URLSessionHTTPTransport` joins the jar's
cookies to any manual `Cookie` header with `; `, a manual value winning by name,
and stores what each response sets. `HTTPCookie` splits the merged `Set-Cookie`,
and `Cookie` refuses a `Domain` the host isn't in, or with no dot, as there is no
public suffix list. `CookieList` applies RFC 6265's rules for storing and sending,
and RFC 6265bis's, so a plain HTTP response can neither set nor replace a Secure
cookie.

A redirect response's cookies can only be read in `willPerformHTTPRedirection`,
which also works `Cookie` out again for the new URL, so jar cookies never follow a
redirect to another host. A manual `Cookie` header follows as other manual headers
do. A session cookie lasts until it is deleted or replaced, as in Postman, so a
login survives a relaunch.

`WorkspaceCookieJar` keeps one workspace's cookies, and `CookieJars` holds one for
each workspace. A send uses the jar of the workspace the app shows, the lowest
`id`. The launch reconcile's merge deletes a workspace, and its cookies and their
items go with it. `AWSSigV4AuthProvider` leaves `Cookie` unsigned, because the jar's
cookies are added after signing. File > Manage Cookies… shows the jar, grouped by
domain, with a value shown only for the selected cookie.

## Sending a Request

Send takes what the tab shows. `RequestDraft.outgoing(from:in:)` puts the draft's
fields over the stored row, because a draft holds no settings or variables, and
replaces `.inherit` from `CollectionTree`, which already holds each container's
decoded auth. A container whose auth can't be read refuses the send rather than
going out with no auth. `DataModel.sendContext` fetches each variable scope, because
a row's to-many arrays go stale on the main context.

`RequestSender` resolves, builds and transmits off the main actor. A typed
credential answers from the draft through a `SecretStore` of its own, so an unsaved
one is sent and never reaches the Keychain. It never logs: a request's URL, headers
and body can each hold a secret.

A send ends in a `SendResult`. `ResponseContent` is worked out there, once, and not
in a view. It goes by the bytes rather than `Content-Type`, because servers mislabel
binary as text. `JSONReindenter` lays out the text the server sent, because
`JSONSerialization` output loses key order and rewrites numbers. A body over 2 MB
stays raw. `ReadOnlyTextView` shows it, because `Text` lays out megabytes on the main
thread.

A credential with no value sends no auth, and the response says so. It also says so
for an unresolved variable, by its reason; a header that isn't valid; an unsupported
auth or body; a form-data file; a body on GET or HEAD; and a manual `Content-Type`
that replaces the form-data boundary. `ResponseNote.notes` keeps them in one order,
naming one and counting several. A note names a row as the tab shows it, because a
resolved name can hold a secret. A request that
can't be built was not sent, so it carries no "sent as written" note.
That includes `{{host}}` in the host with no active environment, which reads "This
URL isn’t valid." A failure after that keeps its notes, because the request went out.

`RequestResponses` holds the latest response for each tab of one window, in memory,
so a relaunch returns to No Response. Cancel shows at once, and each send has a token,
so a result that arrives afterwards lands nowhere. Closing a tab cancels its send and
drops its response, and closing a window cancels.

Request > Send (⌘↩) does what the Send button does, and reads Cancel (⌘.) while the
tab's request is in flight. Request > Edit URL (⌘L) focuses the URL field and selects
its text. Like File > Save, each does nothing while a sheet has the keyboard,
because the focused value outlives the sheet. Both are disabled while a history
entry covers the tabs, so neither acts on a request out of sight.

## History

`RequestSender.sendRecording` returns a send's result with a `HistoryEntry`, and
`RequestResponses` writes it only while its send still holds its token, so a
cancelled send leaves none. A send that failed, or couldn't be built, is recorded
with its failure. The sender builds the entry, because only it holds the raw body.
A body over 5 MB keeps its size and no bytes.

The entry's request is a snapshot of what was sent. A second resolution, against a
secret store that answers nothing, leaves each secret variable as `{{name}}`. It
replays the `{{$guid}}`, `{{$timestamp}}` and `{{$randomInt}}` values the send
drew, in order, so the snapshot holds them. A dynamic variable inside a secret's own
value draws one that the snapshot doesn't, which shifts every later value of that
kind in the record, and Send Again resends the record. The snapshot keeps every
variable in scope, so a secret's value can still name the others. Auth keeps
references, and rows named `Authorization` or `Proxy-Authorization`, and the rows
`rowsReplacedByAuth` names, are masked, so no secret reaches the local store.

Send Again resolves the snapshot against its own variables and the Keychain. A
secret or credential with no value, or a masked row that no auth provider replaces,
as under Digest today, sends nothing and shows "Secret unavailable". Otherwise it
sends and records as Send does.

History belongs to this Mac's one implicit workspace, and its rows carry no
workspace id, because reconcile can replace the workspace row with a synced one of
lower id. `StoreWriter` keeps the newest 500 entries in the save that adds one. A
sidebar row fetches only the `method`, `url`, `statusCode` and `sentAt` columns, so
it reads no blob, and an open entry is read off the main actor. An open entry covers
the tabs in the detail column. They stay live, so ⌘W and the tab commands still act
on the selected tab, and selecting a sidebar row or a tab closes the entry.

## Code Generation

Copy as cURL and Generate Code… take a request out of Moth. A request's context
menu has both, and so does the Request menu, for the current tab. An edited draft
is what they use, as Send does, from any window, because drafts are shared.
Otherwise they use the row, because a tab that isn't selected misses deliveries.
`.inherit` is replaced as it is for Send, and a container whose auth can't be read
shows an alert rather than generating no auth.

`CodeGenerator` takes no `SecretStore`, so what it writes can't hold a secret. It
gives `VariableResolver` a store that answers nothing, so a secret variable stays
`{{name}}`, and a credential is only ever a placeholder: `<password>`, `<token>`
or `<api-key>`. Digest, OAuth 2.0 and AWS Signature leave a comment and no auth.
A secret typed into a plain header or body is plain text, and appears as written.

It doesn't go through `RequestBuilder`, which refuses a URL with a variable left
in it and drops what Send can't send yet. `CodeRequest` holds what both languages
write, so they can't disagree, and `writtenAddress` builds the URL as text, with
what a URL can't hold encoded outside `{{variables}}`. Like Send, it leaves out a
body on GET or HEAD, an API key with no name and a header that can't be sent, each
with a comment, and a manual header or query parameter gives way to the auth that
sets it. A header with a variable left in it stays, because filling it in may make
it valid. Every body kind is
written, with binary as a file reference. A request's settings are not. A form-data
name holding `=` can't be written for cURL, which splits on the first `=`.

cURL quoting works on Unicode scalars, because `'` and a combining mark after it
are one `Character`, which a replacement by `Character` would leave open. Options
are chosen so a value can't change their meaning: `--url` for an address starting
with `-`, and `--data-raw` and `--form-string` for a leading `@`.

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
Cookies stay in Moth's own jar on this Mac, never the system's cookie storage.

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
