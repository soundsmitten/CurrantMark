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
- Windowless application lifecycle; closing the last document does not quit.
- A persisted setting controlling automatic Open dialogs at launch and Dock
  reactivation, enabled by default for new users.
- Finder document metadata for Markdown extensions.
- UTF-8 file loading.
- File watching for writes and atomic-save replacement.
- GFM parsing and HTML formatting through `swift-markdown`.
- Default CSS for typography, code blocks, tables, links, and dark mode.
- WKWebView preview.
- Best-effort vertical scroll restoration after refresh.
- In-window navigation for links to Markdown files.
- Anchor IDs and in-document anchor navigation.
- Native document proxy and filename title.
- Filename breadcrumbs for document history, with stable compressed widths and
  hover expansion that does not reflow neighboring breadcrumbs.
- A links-only dropdown on the current document breadcrumb.
- Folder links that present a Markdown picker rooted at the linked folder.
- Back and Forward toolbar controls that appear after navigation begins.
- One optional same-document horizontal split with independent scroll positions.
- A View-menu command that toggles the split.
- Persistent heading bookmarks with gutter-style preview markers.
- An app-wide Bookmarks menu with current-document and recent destinations.
- A separate Bookmarks window for opening and removing saved locations.
- PDF export from the current rendered document.
- Focused Markdown processor and document-source tests.
- README, agent instructions, project documentation, and MIT license.

## Latest validation

On 2026-09-07, `swift test` completed successfully on arm64 macOS:

- 13 tests executed.
- 0 failures.
- The tests cover GFM headings, task-list checkboxes, tables, stylesheet
  injection, escaped code, links, images, base URLs, UTF-8 file loading, and
  missing-file errors. Preference tests cover the discoverable default and
  persistence of the disabled automatic-picker value. Navigation tests cover
  backward/forward traversal and discarding stale forward history. Processor
  tests cover document indexing, resolved links, heading anchors, and duplicate
  anchor names.
- `swift-markdown` is pinned to an upstream revision with HTML escaping for
  text and code output.
- The CLI was exercised against `README.md`; HTML output succeeded and PDF
  export produced a valid one-page PDF at `/tmp/currantmark-readme.pdf`.
- The programmatic application and File menus were verified in the running app.
- Opening two files in one Finder-style request created two independent
  document windows; closing the front window revealed the other rendered file.
- The first captured rendered window used the dark document background, with
  no empty white preview surface presented.
- The launch picker to rendered-document transition was reproduced after the
  lifecycle fix. The document remained open, and closing it left the
  CurrantMark process running for subsequent Open actions.
- With the automatic-picker preference disabled, a fresh launch remained
  windowless while the CurrantMark process stayed running.
- Bookmark source and persistence tests were added after this validation run;
  the bookmark UI, split-pane implementation, new tests, and persistence round
  trip have not yet been built or exercised at runtime.

## Known limitations

- Scroll restoration currently preserves vertical offset, not a semantic
  heading or element anchor.
- File watcher events are not debounced, so a noisy editor may cause multiple
  quick refreshes.
- External links open in the system browser; in-app webpage navigation is not
  implemented yet.
- Export options are intentionally minimal and use WebKit defaults.
- There is no user-facing error banner or recovery UI beyond an alert.
- Bookmarks currently attach to headings only. Renaming a heading changes its
  generated anchor; the stored excerpt is not yet used to recover that move.
- The Bookmarks window does not yet provide search or grouping controls.

## Deliberately deferred

Editing, project/workspace management, custom syntax, presentation mode,
plugins, Neovim integration, Vim keybindings, AI, collaboration, cloud sync,
theme-management UI, and editor integrations are outside this phase.
