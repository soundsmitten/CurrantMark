# Implementation status

Status is recorded here so agents can distinguish working code from planned
architecture.

## Implemented in the initial foundation

- Swift Package Manager macOS executable target.
- AppKit application lifecycle and minimal File menu.
- `currantmark` CLI for HTML stdout and PDF export.
- Standard Open and Save panels.
- Launch-time Open panel with no empty preview window.
- Multiple document windows, including multi-selection in the Open panel.
- Initial document rendering before a new window is shown.
- Finder document metadata for Markdown extensions.
- UTF-8 file loading.
- File watching for writes and atomic-save replacement.
- GFM parsing and HTML formatting through `swift-markdown`.
- Default CSS for typography, code blocks, tables, links, and dark mode.
- WKWebView preview.
- Best-effort vertical scroll restoration after refresh.
- PDF export from the current rendered document.
- Focused Markdown processor and document-source tests.
- README, agent instructions, project documentation, and MIT license.

## Latest validation

On 2026-09-07, `swift test` completed successfully on arm64 macOS:

- 5 tests executed.
- 0 failures.
- The tests cover GFM headings, task-list checkboxes, tables, stylesheet
  injection, escaped code, links, images, base URLs, UTF-8 file loading, and
  missing-file errors.
- `swift-markdown` is pinned to an upstream revision with HTML escaping for
  text and code output.
- The CLI was exercised against `README.md`; HTML output succeeded and PDF
  export produced a valid one-page PDF at `/tmp/currantmark-readme.pdf`.
- The programmatic application and File menus were verified in the running app.
- Opening two files in one Finder-style request created two independent
  document windows; closing the front window revealed the other rendered file.
- The first captured rendered window used the dark document background, with
  no empty white preview surface presented.

## Known limitations

- Scroll restoration currently preserves vertical offset, not a semantic
  heading or element anchor.
- File watcher events are not debounced, so a noisy editor may cause multiple
  quick refreshes.
- Link handling currently follows WebKit defaults; there is no custom external
  link policy yet.
- Export options are intentionally minimal and use WebKit defaults.
- There is no user-facing error banner or recovery UI beyond an alert.

## Deliberately deferred

Editing, project/workspace management, custom syntax, presentation mode,
plugins, Neovim integration, Vim keybindings, AI, collaboration, cloud sync,
theme-management UI, and editor integrations are outside this phase.
