# Architecture

## Shape

CurrantMark is a small AppKit application with a replaceable document-to-HTML
pipeline:

```text
URL
  ↓
FileDocumentSource ── SourceDocument ── MarkdownProcessor
                                             ↓
                                      RenderedDocument
                                         ↙       ↘
                           DocumentPreviewGroup  PDFExporter
                              ↙       ↓       ↘
                        PreviewView PreviewView  …
                              ↓       ↓
                           WKWebView WKWebView
```

The application shell and CLI wire these pieces together. The rendering
pipeline is not responsible for windows, menus, file watching, or PDF save
panels.

## Components

### Application shell

`main.swift` explicitly creates `NSApplication.shared`, installs the
programmatic main menu, assigns `AppDelegate`, and starts the AppKit run loop.
`AppDelegate` owns Finder-opened URLs and the collection of open document
windows. A normal launch opens the standard file picker without first showing
an empty window. Finder-opened files bypass the picker. Each selected document
gets its own window; reopening an already-open URL focuses its existing window.
File > Duplicate Window is the explicit exception: it creates a second
`MainWindowController` for the active document with independent navigation,
scroll, split, zoom, and file-watching state.
The application-owned File and Window menus route standard window operations
through AppKit and export through the active document controller.
Closing the final document does not terminate the application. Reopening the
windowless app from the Dock presents the Open panel only when the corresponding
user preference is enabled. `AppPreferences` owns this persisted policy, and a
small programmatic AppKit Settings window exposes it.
`MainWindowController` owns one document session and wires
the injected source, processor, preview group, and exporter together. The
`CurrantMarkCLI` executable uses the same core processor and exporter without
creating an AppKit window.

This is intentionally a small shell. It is not a general coordinator layer.

### Document source

`DocumentSource` represents readable document input plus change observation.
`FileDocumentSource` is the current implementation. It reads UTF-8 Markdown
from a URL and uses a Dispatch source to observe writes, renames, and deletes.
Atomic-save replacement is handled by reattaching the watcher when the path is
created again.

Future editor or unsaved-buffer sources should implement this boundary without
changing Markdown processing or WebKit presentation.

### Markdown processing

`MarkdownProcessor` accepts Markdown, a `RenderStyle`, and an optional base URL;
it returns a `RenderedDocument`. `SwiftMarkdownProcessor` delegates parsing
and HTML formatting to the `swift-markdown` package, whose parser is backed by
GitHub-Flavored Markdown support.

The app does not own a Markdown grammar. A future processor such as Apex can
implement `MarkdownProcessor` and preserve the rest of the flow.

### Rendered document

`RenderedDocument` contains the complete HTML document, the base URL used for
relative images and links, and a compact `DocumentIndex`. The index records the
top heading, headings with stable generated anchors, and resolved links from
the same parsed Markdown tree. It is the shared handoff between rendering,
preview, navigation UI, and export.

### Styling

`RenderStyle` carries stylesheet content into the processor. The default CSS is
the packaged `Resources/Style.css`. Styling is therefore an input to document
generation, while the view controller only chooses the current style.

### Preview

`PreviewView` owns the WKWebView boundary. Before a refresh it asks JavaScript
for `window.scrollY`; after navigation completes it restores that offset. This
is deliberately “reasonable” preservation rather than a fragile attempt to
map exact document anchors across arbitrary edits.

`DocumentPreviewGroup` owns the `NSSplitView`, its primary `PreviewView`, and an
optional second `PreviewView`. Both panes consume the window's same
`RenderedDocument`, bookmark state, and link actions, while retaining their own
WebKit scroll positions. Before showing a split, the group captures the active
pane's vertical offset and pre-renders the second pane offscreen at its future
half-width and that offset. It inserts the ready pane only after navigation and
scroll restoration complete. The group strongly owns that pending pane during
its asynchronous first load and reports the session as split while preparation
is underway. Cross-document navigation updates the whole document session and
therefore both panes; a window never contains unrelated documents.

Page zoom is window-level reading state owned by `DocumentPreviewGroup`.
Bigger, Smaller, and Actual Size commands update WebKit's page zoom for every
pane in the window, including a second pane created after the zoom changes.
The panes continue to own independent scroll positions.

Each `PreviewView` uses the native text background color and keeps its WebKit
surface hidden until its first HTML navigation and requested scroll restoration
complete. New document windows use that masking directly; split panes also
pre-render offscreen so the visible layout changes only when the pane is ready.
Preview-only code-block buttons send their code text through a narrow WebKit
message handler to the native pasteboard and briefly replace the clipboard icon
with a checkmark. The injected controls are absent from `RenderedDocument`, so
they do not appear in PDF output.

### Document navigation

`PreviewView` reports activated links without deciding how the application
should open them. `MainWindowController` follows links to supported Markdown
files in the current window and records their URLs in
`DocumentNavigationHistory`. Native toolbar actions move backward and forward
through that history and are disabled when their direction is unavailable.
They are installed with the toolbar rather than inserted during navigation,
avoiding an AppKit assertion seen when opening links. Folder links present a
Markdown-filtered Open panel rooted at that folder. Anchor links scroll to IDs
generated by the Markdown processor. Other URLs are handed to the system for
now; in-app web navigation remains a later, separate document-session
capability.

The native title and represented URL preserve the macOS document proxy. A
small content bar beneath the toolbar shows filename breadcrumbs for the
document navigation history. Breadcrumb widths are independent of selection
and hover state. When space is limited, segments use stable compressed widths;
hovering temporarily expands one segment over its neighbors without reflowing
the row. Clicking the current segment opens its links, while Space or
Command-click can open the links for any segment that has them. These menus are
built from `DocumentIndex`; a future outline sidebar will own heading
navigation. Clicking the current segment when it has no links is a no-op; a
same-document selection never detaches that document from its breadcrumb
ancestry.

The Edit > Find command opens a native AppKit search bar backed by WebKit's
page-level find API and searches the currently active preview pane. Search is
presentation behavior over the rendered HTML; it does not add a second
Markdown parser or alter the shared `RenderedDocument` consumed by preview and
export. The bar reports a positive match count derived from the rendered page's
visible text and leaves the count area empty when there are no matches.

### PDF export

`WebKitPDFExporter` loads the same `RenderedDocument` HTML into an off-screen
WKWebView and calls WebKit’s PDF API after navigation completes. The save panel
and file naming policy remain in `MainWindowController`; the exporter only
knows how to turn rendered HTML into PDF data at a destination URL.

The CLI supplies its output URL as an argument and waits on the main run loop
until the same exporter completes.

## Ownership and lifecycle

- `AppDelegate` strongly owns all open document window controllers.
- Each `MainWindowController` owns one active source and rendered document.
- Each `DocumentPreviewGroup` owns the split view and its preview panes.
- `FileDocumentSource` owns its file descriptor and Dispatch source.
- Each `PreviewView` owns its WKWebView, scroll state, and navigation delegate.
- `WebKitPDFExporter` temporarily retains its export web view and delegate
  until PDF generation completes.

There is no global application store or singleton service registry.

## Extension seams

| Future need | Existing seam |
| --- | --- |
| Another Markdown engine | `MarkdownProcessor` |
| Unsaved/editor-backed input | `DocumentSource` |
| Custom or bundled styles | `RenderStyle` and resource loading |
| Alternate PDF or export format | `PDFExporter` |
| Command palette | `MainWindowController` actions and injected services |
| Presentation mode | A new presentation surface consuming `RenderedDocument` |
| Same-document split panes | `DocumentPreviewGroup` |
| Linked-document navigation | `DocumentNavigationHistory` and Preview link callback |
| Alternate bookmark persistence | `BookmarkStore` |

These seams are intentional. Plugin APIs, theme registries, workspace models,
and command buses are not part of the current architecture.

### Bookmarks

`DocumentBookmark` identifies a heading by document URL and generated anchor,
and retains its heading text as a recovery hint. `BookmarkController` owns the
application-level toggle, removal, lookup, and URL-resolution actions.
`BookmarkStore` is the narrow persistence boundary: `JSONBookmarkStore` writes
a versioned library atomically under the user's Application Support directory.
Security-scoped bookmark data is retained when the platform can create it so
future sandboxed builds can resolve previously selected documents.

The document gutter, dynamic Bookmarks menu, and `BookmarksWindowController`
all consume the same controller. Preview injects heading marker controls only
into its displayed WebKit document; those controls are not part of
`RenderedDocument`, so PDF output remains unchanged. The initial implementation
bookmarks headings because they already have processor-generated stable IDs.
