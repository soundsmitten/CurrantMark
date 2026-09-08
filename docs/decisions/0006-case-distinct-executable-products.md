# ADR 0006: Case-distinct executable product names

## Status

Accepted

## Context

Swift Package Manager placed GUI product `CurrantMark` and CLI product
`currantmark` at the same path on the default case-insensitive macOS filesystem.
Parallel links could overwrite either executable before ad-hoc signing,
producing intermittent strict-validation failures.

## Decision

The Swift package names the GUI build product `CurrantMarkApp` and keeps the
command-line product `currantmark`. The packaging script copies
`CurrantMarkApp` into the bundle as `Contents/MacOS/CurrantMark`, preserving the
public application executable and bundle metadata. It embeds the CLI separately
at `Contents/Helpers/currantmark`, where it can share the app's packaged style
without colliding with the primary executable.

## Consequences

GUI and CLI builds no longer share an output path. The user-facing app remains
CurrantMark, and the command-line interface remains `currantmark`. Moving the
app also moves a usable CLI, although installing a convenience symlink into a
shell `PATH` remains a separate distribution concern.
