# ADR 0009: Explicit duplicate document windows

## Status

Accepted

## Context

Ordinary macOS Open behavior should avoid surprising duplicate windows for the
same file. A reader may still want two independently placed views of one
Markdown document, with separate navigation, scroll, split, and zoom state.
The same-document split is not a substitute because its panes deliberately
share one window-level document session.

## Decision

Ordinary Open panel and Finder requests continue to focus an existing window
for an already-open URL. File > Duplicate Window explicitly creates another
`MainWindowController` for the active document and bypasses that deduplication.
Each duplicate owns an independent document session and file watcher.

## Consequences

The same URL can appear in multiple windows only through an explicit command.
Duplicate windows can navigate and change reading state independently while
refreshing from the same on-disk file. This adds duplicate rendering and
watching work when the user requests it. Commands that reuse an already-open
document, such as bookmark navigation, may choose any existing instance.

Making every Open request create a new window was rejected because it makes a
common operation unpredictable. Tabs and a multi-document window coordinator
remain separate, deferred product decisions.
