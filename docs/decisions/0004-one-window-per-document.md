# ADR 0004: One window per document

## Status

Accepted

## Context

CurrantMark may receive several files from Finder or from a multi-selection in
the Open panel. Reusing one window would discard the user's current reading
context and make side-by-side reference impossible.

## Decision

The application delegate owns a collection of document window controllers.
Each controller owns one document source, rendered document, preview, watcher,
and export action. Opening an already-open URL focuses its existing window.
The File menu remains application-owned and routes export to the key window.

## Consequences

Multiple Markdown files can remain open and refresh independently. Future
window-level commands have an explicit active-document target without adding a
global document store. Session restoration remains deferred.
