# ADR 0001: SwiftPM app with a shared HTML render model

- Status: accepted
- Date: 2026-09-07

## Context

CurrantMark needs a native macOS shell, a GFM Markdown parser, a live preview,
and PDF output that matches the preview. The project is starting from an empty
repository and should remain easy to build from a fresh checkout.

## Decision

Use a Swift Package Manager executable target with AppKit and WebKit. Use a
pinned upstream revision of `swift-markdown` for parsing and HTML formatting;
the pin includes HTML escaping for text and code output. Represent the output as a
small `RenderedDocument` containing HTML and an optional base URL. Feed that
same model to WKWebView preview and WebKit PDF export. Provide a small script
that wraps the release executable in a Finder-openable `.app` bundle.

## Consequences

- The repository has one source-of-truth package manifest and no generated
  Xcode project to keep synchronized.
- The app depends on one focused external package instead of owning a parser.
- Preview and export cannot silently drift into separate Markdown pipelines.
- A future processor can replace `swift-markdown` behind `MarkdownProcessor`.
- Packaging is intentionally script-based and may later grow signing,
  notarization, or a dedicated project only when the product needs it.

## Alternatives considered

- A hand-written Markdown parser: rejected because it creates unnecessary
  syntax and compatibility maintenance.
- A separate Markdown-to-PDF path: rejected because preview/export drift would
  be likely.
- A generated Xcode project: deferred because it adds state without improving
  this initial source layout.
