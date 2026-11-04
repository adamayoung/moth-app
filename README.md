# Moth

A native macOS API client. Send HTTP requests, organise them into collections,
and switch between environments.

Moth is in early development and isn't usable yet.

## It Stays in Its Box

Moth sends the requests you ask it to send, and does nothing else on your Mac.

- **No telemetry.** No analytics, no crash reporting, no usage tracking.
- **No account.** There is nothing to sign up for. Your data syncs through your
  own iCloud account.
- **No touching other tools' config.** Moth never installs plugins or hooks, and
  never edits the settings of your editor, your coding agents or anything else.

The only network traffic is the requests you send and iCloud sync.

## Planned

- Collections, folders and requests, synced through iCloud
- Environments and `{{variable}}` interpolation
- Secrets kept in the Keychain, never in the database
- Pretty JSON responses, with headers and timing
- Postman Collection v2.1 and Environment import, for bringing your work with you
- More authentication types, history, cURL import and code generation

See the [roadmap](docs/roadmap.md).

## Requirements

- macOS 27.2 or later
- Xcode 27.2 or later to build

## Contributing

Start with the [documentation guide](docs/README.md).

## Licence

MIT
