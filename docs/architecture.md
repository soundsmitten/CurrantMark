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
                                  PreviewView   PDFExporter
                                      ↓
                                  WKWebView
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
The application-owned File and Window menus route standard window operations
through AppKit and export through the active document controller.
`MainWindowController` owns one document session and wires
the injected source, processor, preview, and exporter together. The
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

`RenderedDocument` contains the complete HTML document and the base URL used
for relative images and links. It is the shared handoff between rendering,
preview, and export. Keeping this model small prevents PDF export from growing
into a second Markdown pipeline.

### Styling

`RenderStyle` carries stylesheet content into the processor. The default CSS is
the packaged `Resources/Style.css`. Styling is therefore an input to document
generation, while the view controller only chooses the current style.

### Preview

`PreviewView` owns the WKWebView boundary. Before a refresh it asks JavaScript
for `window.scrollY`; after navigation completes it restores that offset. This
is deliberately “reasonable” preservation rather than a fragile attempt to
map exact document anchors across arbitrary edits.

The WKWebView and its host window use the native text background color. A new
document window remains hidden until its first HTML navigation completes,
preventing the default unrendered WebKit surface from flashing onscreen.

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
- `FileDocumentSource` owns its file descriptor and Dispatch source.
- `PreviewView` owns its WKWebView and navigation delegate.
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

These seams are intentional. Plugin APIs, theme registries, workspace models,
and command buses are not part of the current architecture.
