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
- Keyboard navigation for the breadcrumb bar: a shortcut focuses it, arrow
  keys move between segments, Space peeks the focused segment's link dropdown
  (any segment with known links, not only the current one) without navigating
  or losing focus, Return navigates the focused segment without touching the
  dropdown, Escape returns focus to the document, and Cmd-click is the mouse
  equivalent of Space.
- One optional same-document horizontal split with independent scroll positions.
- A View-menu command that toggles the split, and a keyboard shortcut that
  cycles keyboard focus between the two panes.
- Persistent heading bookmarks with gutter-style preview markers.
- An app-wide Bookmarks menu with current-document and recent destinations.
- A separate Bookmarks window for opening and removing saved locations.
- Opening a bookmark reuses the active window (or an already-open window for
  that document) instead of always opening a new one.
- PDF export from the current rendered document.
- Focused Markdown processor and document-source tests.
- README, agent instructions, project documentation, and MIT license.

## Latest validation

On 2026-09-07, `swift build` and `swift test` completed successfully on arm64
macOS (Swift 6.3.1), and the built app was run and exercised interactively,
covering the bookmark and split-pane/navigation work:

- Both executables (`CurrantMarkApp` and `currantmark`) built cleanly.
- 20 tests executed, 0 failures.
- The tests cover GFM headings, task-list checkboxes, tables, stylesheet
  injection, escaped code, links, images, base URLs, UTF-8 file loading,
  missing-file errors, document indexing, resolved links, heading anchors,
  duplicate anchor names, and `<base>` tag emission/escaping. Preference tests
  cover the discoverable default and persistence of the disabled
  automatic-picker value. Navigation tests cover backward/forward traversal
  and discarding stale forward history. Bookmark tests cover toggling a
  heading bookmark on and off and leaving the in-memory library unchanged when
  persistence fails.
- Building surfaced one real defect, now fixed: `Sources/CurrantMark/main.swift`
  called the `@MainActor`-isolated `AppDelegate()` initializer and
  `makeMainMenu()` from the nonisolated top-level `main.swift` context, which
  the Swift 6 compiler rejects as a strict-concurrency error. Both calls are
  now wrapped in `MainActor.assumeIsolated`, which is safe because top-level
  `main.swift` code always runs synchronously on the main thread before any
  concurrency infrastructure starts.
- Interactive testing surfaced and fixed four further defects, none caught by
  the test suite because they require a real WKWebView or window:
  - `PreviewView.scrollToAnchor(_:)` used `NSJSONSerialization` on a bare
    `String`, which raises an uncaught Objective-C exception (not a catchable
    Swift error) and crashed the app the first time a split pane synced its
    scroll position. Fixed by switching to `JSONEncoder`.
  - Adding a second split pane did not give it a visible width, since
    `NSSplitView.addArrangedSubview` does not itself redistribute space from
    an existing pane that already fills the view. Fixed by explicitly setting
    the divider position to the midpoint after the second pane is added.
  - `WKWebView.loadHTMLString(_:baseURL:)` does not grant the WebContent
    process read access to local files referenced by relative path, so
    Markdown images on disk silently failed to load in both the preview and
    PDF export. Fixed by writing the generated HTML to a temporary file and
    loading it with `loadFileURL(_:allowingReadAccessTo:)`, with a `<base
    href>` tag injected into the HTML so relative references still resolve
    against the real document location rather than the temp file's location.
  - The breadcrumb bar and the Settings checkbox showed a system focus ring
    the moment their window first appeared. Root cause: leaving
    `NSWindow.initialFirstResponder` nil lets AppKit auto-generate a key view
    loop the first time a window is shown and assign initial first-responder
    status to the first control in it, independent of any
    `makeFirstResponder` call made earlier during `init`. Fixed by pointing
    `initialFirstResponder` at each window's inert content view. A related
    false-positive hover (`BreadcrumbButton`'s tracking area lacked
    `.assumeInside`) was fixed the same way.
- Follow-on interactive testing of the breadcrumb keyboard/mouse model went
  through several corrections before landing on the behavior described above:
  Return originally simulated a click and could open the dropdown instead of
  navigating; Space originally only worked on the current segment and did not
  keep focus in the bar after the dropdown closed; the pane-cycling shortcut
  was moved from Control-Tab to Control-Return because Control-Tab is
  reserved by macOS for window/tab switching and never reaches the app. Link
  data for non-current segments is served from a per-URL cache populated as
  each document is rendered, since `DocumentNavigationHistory` itself only
  stores URLs.
- `swift-markdown` is pinned to an upstream revision with HTML escaping for
  text and code output.
- Remaining unverified areas: the CLI's PDF export path has not been manually
  re-tested with an image-containing document since the local-image-loading
  fix.

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
