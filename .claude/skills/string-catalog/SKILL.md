---
name: string-catalog
description: Add, change, pluralise or delete a user-facing string in Moth's Localizable.xcstrings — the two plural shapes the catalog supports, the xcstringstool constraint that rules one of them out, and the traps that survive review. Use when adding a localised key, making a string count-aware, hand-editing Localizable.xcstrings, or changing text that a test mirrors by hand.
---

# Localised strings in the string catalog

`Moth/Resources/Localizable.xcstrings` — one catalog, source language
`en-GB`, keys in screaming snake case naming the string's *role* rather than its
text. `docs/code-style.md` ("User-Facing Content and Comments") says which
catalog a string belongs in; this skill owns the plural rule, the procedure
and the failure modes.

Apple's reference is
[Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog).

## The rule

**A string whose text contains a count is varied by plural in the catalog. One
key.** Never a `count == 1 ? "FOO" : "FOOS"` pair chosen in Swift.

A ternary produces exactly two branches. Polish and Russian need `few` and
`many` besides `one` and `other`, so a ternary makes those languages a *code*
change. Varied in the catalog, Xcode "automatically adds the language-specific
variations for those languages" when the language is added — One/Other for
English, One/Few/Many/Other for Russian — and the string stays translator-side.
Source-language variants and per-language variants stay in sync automatically;
a variant added to a non-source language affects only that language.

There is one exception, and the compiler enforces it — see below.

## The two shapes

Write the key as a literal with the count interpolated so the extractor sees it
(`String(localized: "SAVED_REQUEST_COUNT_\(count)")`), build, then
Control-click the key in the string catalog editor and choose **Vary by
Plural**. Hand-editing the JSON is fine too; these are the two shapes it
produces.

**Whole-string variations** — one argument, the count in the text. The key keeps
its `%lld` suffix and `variations.plural` replaces the `stringUnit`. Model:
`SAVED_REQUEST_COUNT_%lld`.

```json
"SAVED_REQUEST_COUNT_%lld" : {
  "comment" : "Shown under a collection's name in the sidebar: how many saved requests it holds. The argument is the number of requests.",
  "localizations" : {
    "en-GB" : {
      "variations" : {
        "plural" : {
          "one" : { "stringUnit" : { "state" : "translated", "value" : "%lld Saved Request" } },
          "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld Saved Requests" } }
        }
      }
    }
  }
}
```

**Substitutions** — more than one argument, only one of them driving the plural.
The value references `%#@name@`; a `substitutions.name` block carries `argNum`
(1-based, matching the `%n$` position), `formatSpecifier` (no `%`) and the
variations, which use `%arg` where the number goes. Model:
`IMPORTING_STATUS_%lld_OF_%lld`.

```json
"en-GB" : {
  "stringUnit" : { "state" : "translated", "value" : "Importing… %1$lld of %#@requests@" },
  "substitutions" : {
    "requests" : {
      "argNum" : 2,
      "formatSpecifier" : "lld",
      "variations" : {
        "plural" : {
          "one" : { "stringUnit" : { "state" : "translated", "value" : "%arg Request" } },
          "other" : { "stringUnit" : { "state" : "translated", "value" : "%arg Requests" } }
        }
      }
    }
  }
}
```

The same menu and the same file shape cover **Vary by Device**
(`variations.device`) when a string has to read differently on iPhone and Mac.
Moth is macOS-only for now and uses none.

## The exception the compiler enforces

**A string that never displays its count cannot be varied.** A title shown
beside a number the view draws in its own `Text` reads "Open Request" or
"Open Requests" with no specifier anywhere. Interpolating the count into
the *key* to select a variant does not satisfy the tool — the **value** must
reference the number:

```
Localizable.xcstrings:0 — error: Plural variation requires referencing the
number in the string (OPEN_REQUESTS_%lld)
```

Its own advice is "separate top-level strings should be used for singular and
plural cases". So such a title picks between a singular and a
plural key with a ternary, and each key carries a comment naming its other
half. That is the whole exception: **if the count is in the text, it
varies in the catalog.**

## Pitfalls

1. **Vary by Plural prepopulates both variants with the existing plural text.**
   The `one` case arrives holding the plural's verb and article, not just its
   noun. "%lld request **are** waiting to send" is what ships if you only fix
   the noun. Read the whole sentence in both variants.
2. **Converting a pair leaves the comments lying.** A comment that read "Shown
   when *several* requests are waiting" describes the key it used to be.
   Rewrite it to describe a key that now covers every count.
3. **A multi-argument string with no variations pluralises nothing.**
   "Importing… 1 of 1 requests" was live for as long as the key had a
   flat `stringUnit`. Any string with two counts needs checking at 1.
4. **Put a whole clause inside a substitution, not a bare `%arg`.** Leaving the
   surrounding words in the parent string hands a translator a numeral to
   inflect and no sentence to put it in.
5. **Everything that mirrors the string by hand has to mirror the plural.**
   UI screen objects hold copies of localised labels by design, and unit tests
   assert rendered English. Grep the string, not just the key.
6. **`make test` does not compile the UI test target.** An edit to a screen
   object is unverified until a targeted `make test-ui
   TESTS=<Class>` runs. A green unit suite says nothing about it.
7. **Deleting a key needs a full grep first** — Swift, `MothUITests` and
   `docs/`.
8. **Catalog errors report at line 0.** The key name in the parentheses is the
   only locator you get; there is no line number to jump to.
9. **Hand-edited JSON must keep Xcode's formatting**: two-space indent and
   `"key" : {` with spaces around the colon. Keys sort with underscores
   ignored, so replace a block in place rather than appending, and
   re-validate with `python3 -c "import json; json.load(open(...))"` before
   building.

## Verify

In cost order:

- `python3 -c "import json; json.load(open('Moth/Resources/Localizable.xcstrings'))"`
  after any hand edit — a broken catalog fails the build with a parse error that
  says nothing useful.
- `make test` — compiles the catalog (that is where the plural-variation error
  surfaces) and runs the tests that assert rendered English.
- `make test-ui TESTS=<Class> UI_ALLOWANCE=short` — only if a screen object mirrors
  the string. Never a bare `make test-ui`.

Run all of these through the `tooling-runner` agent, per `CLAUDE.md`.

## Xcode's own catalog tools

`StringCatalogRead`, `StringCatalogContext` and `StringCatalogEdit` exist on the
Xcode MCP server. They are built for *translating into a target locale* — each
takes a `targetLocaleIdentifier`, and each demands an `xcode-integration:*`
skill be activated first. `StringCatalogEdit` does accept the plural shapes
(`variationTranslation`, `templateTranslation`), so it can vary a string, but
this repo's source-language edits have so far been made directly against the
JSON. Prefer the direct edit for restructuring keys; reach for these when adding
a language.
