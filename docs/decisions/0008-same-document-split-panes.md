# 0008: Keep split panes within one document session

## Status

Accepted

## Context

Readers may need to compare distant parts of one long document. Treating each
pane as a separate document session would duplicate file watchers and rendering
work, weaken the native one-document-per-window model, and drift toward project
or workspace management.

## Decision

One `MainWindowController` continues to own one source, rendered document, and
navigation history. Its `DocumentPreviewGroup` may present that document in a
primary and one optional secondary `PreviewView` managed by `NSSplitView`. The
two panes keep independent WebKit scroll positions but share document reloads,
links, and bookmark state. One toggle command shows or hides the secondary
pane. Cross-document navigation replaces the document in both panes. Different
documents remain separate windows.

## Consequences

Live refresh still reads and renders once per document window, then fans the
result out to both panes. Adding alternate split orientations later remains a
presentation change. The current phase intentionally supports only one split
and does not support panes showing different documents.
