# 0010: Swift 6 complete concurrency

## Context

CurrantMark already isolates AppKit and WebKit presentation on the main actor
and marks the shared document models as `Sendable`. The package was still
declared with Swift tools 5.9, leaving the language mode implicit.

## Decision

Use Swift tools 6.0 and declare Swift 6 language mode for every package target.
This makes complete concurrency checking a package invariant rather than an
individual developer or compiler configuration choice.

The application shell remains `@MainActor`-isolated. Core value models remain
`Sendable`; file watching and other platform callbacks must preserve those
boundaries when they are changed.

## Alternatives considered

- Keep Swift tools 5.9 and enable strict concurrency only through target flags:
  this would check concurrency without making Swift 6 language semantics
  explicit in the package manifest.
- Migrate individual files opportunistically: this would leave the package
  with inconsistent compiler guarantees.

## Validation boundary

This change was verified statically with manifest inspection and repository
checks. A Swift build or test run remains intentionally deferred until
explicitly requested.
