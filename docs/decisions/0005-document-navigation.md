# ADR 0005: Application-owned document navigation

## Status

Accepted

## Context

WKWebView can follow links, but a relative link to another Markdown file would
display raw source and would bypass CurrantMark's processor and file watcher.
Navigation must preserve the rendered-document pipeline.

## Decision

Preview reports user-activated links to its owning document session. Markdown
file links are rendered in the current window and recorded in a small
application-owned URL history. Back and Forward actions traverse that history.
The processor emits a compact index from its existing Markdown AST so anchors
and link menus do not scrape rendered WebKit content. A content bar presents
history as filename breadcrumbs; headings remain reserved for a future outline.
Compressed breadcrumb widths stay stable across selection and hover changes,
with hover expansion drawn over neighboring segments. Folder links present a
Markdown-filtered picker. Non-Markdown URLs remain system-owned until web
document sessions are added.

## Consequences

Linked README and documentation files remain rendered, watched, and exportable.
Navigation state and index generation are testable without AppKit. A future
outline sidebar can consume the heading metadata, and web browsing can add its
own session behavior without changing the Markdown grammar.
