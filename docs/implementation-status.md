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

On 2026-09-07, `swift build` and `swift test` completed successfully on arm64
macOS (Swift 6.3.1), covering the bookmark and split-pane/navigation work:

- Both executables (`CurrantMarkApp` and `currantmark`) built cleanly.
- 17 tests executed, 0 failures.
- The tests cover GFM headings, task-list checkboxes, tables, stylesheet
  injection, escaped code, links, images, base URLs, UTF-8 file loading,
  missing-file errors, document indexing, resolved links, heading anchors, and
  duplicate anchor names. Preference tests cover the discoverable default and
  persistence of the disabled automatic-picker value. Navigation tests cover
  backward/forward traversal and discarding stale forward history. Bookmark
  tests cover toggling a heading bookmark on and off and leaving the in-memory
  library unchanged when persistence fails.
- Building surfaced one real defect, now fixed: `Sources/CurrantMark/main.swift`
  called the `@MainActor`-isolated `AppDelegate()` initializer and
  `makeMainMenu()` from the nonisolated top-level `main.swift` context, which
  the Swift 6 compiler rejects as a strict-concurrency error. Both calls are
  now wrapped in `MainActor.assumeIsolated`, which is safe because top-level
  `main.swift` code always runs synchronously on the main thread before any
  concurrency infrastructure starts.
- `swift-markdown` is pinned to an upstream revision with HTML escaping for
  text and code output.
- This was a build/test-only validation. The CLI's PDF export, the running
  app's menus, window lifecycle, split-pane behavior, and bookmark gutter UI
  have not been exercised interactively since the bookmark and navigation
  features landed.

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
