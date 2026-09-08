# Implementation status

Status is recorded here so agents can distinguish working code from planned
architecture.

## Implemented in the initial foundation

- Swift Package Manager macOS executable target.
- AppKit application lifecycle and minimal File menu.
- `currantmark` CLI for HTML stdout and PDF export.
- App packaging embeds the CLI at `Contents/Helpers/currantmark`.
- Standard Open and Save panels.
- Launch-time Open panel with no empty preview window.
- Multiple document windows, including multi-selection in the Open panel.
- Explicit duplicate windows for independent reading sessions of the same
  document, while ordinary Open and Finder requests continue to focus an
  existing window for that URL.
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
- Filename breadcrumbs showing the document's ancestor path (the chain of
  link-followed parents back to a root), not a flat visit log, with stable
  compressed widths and hover expansion that does not reflow neighboring
  breadcrumbs. Navigating to a document that is already an ancestor of the
  current one (via a breadcrumb segment or a dropdown link) collapses the
  path to that ancestor instead of appending a duplicate segment.
- A links-only dropdown without a persistent disclosure icon: clicking the
  current breadcrumb opens its links, and Space or Command-click opens links
  for any breadcrumb segment that has them. Clicking the current breadcrumb
  when it has no links does nothing and preserves the existing ancestor path.
- Folder links that present a Markdown picker rooted at the linked folder.
- Back and Forward toolbar controls backed by a true chronological visit
  stack, independent of the breadcrumb's ancestor path: every real navigation
  always pushes, so Back/Forward return to whatever was actually viewed, in
  the order it was actually viewed, even after out-of-order breadcrumb or
  dropdown clicks. The controls remain present and are disabled when their
  direction is unavailable.
- Keyboard navigation for the breadcrumb bar: a shortcut focuses it, arrow
  keys move between segments, Space peeks the focused segment's link dropdown
  (any segment with known links, not only the current one) without navigating
  or losing focus, Return navigates the focused segment without touching the
  dropdown, Escape returns focus to the document, and Cmd-click is the mouse
  equivalent of Space.
- One optional same-document horizontal split with independent scroll
  positions and exact initial vertical-offset synchronization.
- Offscreen pre-rendering and first-load masking for newly created split panes,
  so the visible split opens only after WebKit content and its initial scroll
  offset are ready.
- A View-menu command that toggles the split, and a keyboard shortcut that
  cycles keyboard focus between the two panes.
- Window-level page zoom shared by both panes, with Bigger (Command-=), Smaller
  (Command--), and Actual Size (Command-0) commands.
- Persistent heading bookmarks with gutter-style preview markers.
- An app-wide Bookmarks menu with current-document and recent destinations.
- A separate Bookmarks window for opening and removing saved locations.
- Opening a bookmark reuses the active window (or an already-open window for
  that document) instead of always opening a new one.
- PDF export from the current rendered document.
- Native Find search within the active preview pane, with a compact match count
  and previous/next controls.
- Hover-revealed code-block copy buttons with native clipboard transfer and a
  brief checkmark confirmation.
- First-document reveal waits an additional main-loop turn after WebKit
  navigation, avoiding presentation of its blank initial backing store.
- Focused Markdown processor and document-source tests.
- README, agent instructions, project documentation, and MIT license.

## Latest validation

On 2026-09-07, `swift build` and `swift test` completed successfully on arm64
macOS (Swift 6.3.1), and the built app was run and exercised interactively,
covering the bookmark and split-pane/navigation work:

- Both executables (`CurrantMarkApp` and `currantmark`) built cleanly.
- `Scripts/build-app.sh` packaged the CLI at
  `CurrantMark.app/Contents/Helpers/currantmark`; that embedded executable
  produced styled HTML from `README.md` and exported a valid one-page PDF.
- 23 tests executed, 0 failures.
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
  the Swift 6 compiler rejects as a strict-concurrency error. AppKit setup and
  the blocking run loop now live inside one `MainActor.assumeIsolated` scope,
  so non-Sendable AppKit objects never cross the isolation boundary. This is
  safe because top-level `main.swift` code runs synchronously on the main
  thread before concurrency infrastructure starts.
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
- The original breadcrumb model rendered the entire chronological visit log
  as segments, so re-visiting a document (for example, picking an earlier
  breadcrumb or a dropdown link back to something upstream) appended a
  duplicate segment instead of collapsing, and Back/Forward silently used
  breadcrumb-array position instead of true visit order once a segment was
  clicked out of order. `DocumentNavigationHistory` was redesigned around two
  independent tracks: a chronological visit stack that Back/Forward operate
  on unconditionally, and a parent/child ancestor tree, updated only by real
  link-driven navigation, that the breadcrumb bar renders as `path`.
  Navigating to an existing ancestor reuses that relationship (cycle-safe,
  bounded walk) instead of creating a new edge; unrelated navigation (a
  bookmark, File > Open) starts a fresh single-segment path unless the target
  is already an ancestor, in which case it jumps there instead. Verified with
  four new regression tests covering out-of-order Back/Forward, path
  collapsing on ancestor revisit, and both branches of unrelated navigation,
  plus manual interactive retesting confirmed by the user.
- `swift-markdown` is pinned to an upstream revision with HTML escaping for
  text and code output.
- Remaining unverified area: the initial-window compositor-delay adjustment
  has not yet been exercised interactively.

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
- The Bookmarks window does not yet provide search or grouping controls; Find
  searches the rendered document in the active preview pane.

## Deliberately deferred

Editing, project/workspace management, custom syntax, presentation mode,
plugins, Neovim integration, Vim keybindings, AI, collaboration, cloud sync,
theme-management UI, and editor integrations are outside this phase.
