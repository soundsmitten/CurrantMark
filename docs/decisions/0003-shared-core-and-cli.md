# ADR 0003: Share the rendering pipeline with a CLI

- Status: accepted
- Date: 2026-09-07

## Context

The native GUI is useful for daily reading, but automation and editor
workflows need a command-line entry point. Duplicating Markdown loading,
styling, or PDF preparation in a CLI would create drift from the app.

## Decision

Move document models, file sources, Markdown processing, styling resources,
and WebKit PDF export into `CurrantMarkCore`. Keep the GUI shell in the
`CurrantMark` executable and add a `currantmark` executable that consumes the
same core pipeline.

The CLI supports HTML to standard output and PDF export to an explicit path:

```sh
currantmark FILE.md
currantmark export FILE.md --pdf OUTPUT.pdf
```

## Consequences

- GUI preview, GUI export, and CLI export share the same rendered document
  model.
- CLI automation does not need to open a visible window.
- WebKit PDF export still requires a macOS run loop, so the CLI owns a small
  synchronous wait around the asynchronous exporter.
- A future CLI command can be added without making the AppKit window
  controller a general-purpose command router.
