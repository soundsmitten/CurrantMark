# Product scope

## Current goal

CurrantMark should be a daily-use native macOS Markdown Browser: open a
Markdown file, render it cleanly, follow links between documents, refresh when
it changes, preserve the reader’s place, and export the rendered result to
PDF.

## Current requirements

- Open Markdown files through a standard Open panel.
- Open Markdown files from Finder.
- Open each document in its own native window.
- Show one optional second pane for an independently scrollable position in the
  same document; never mix different documents in one window's split view.
- Follow links between Markdown files with Back and Forward navigation.
- Follow anchor and folder links without exposing raw Markdown.
- Bookmark headings from the preview and revisit them from an app-wide menu or
  Bookmarks window.
- Search the rendered document with the native Find interface.
- Render GitHub-Flavored Markdown.
- Refresh automatically after on-disk changes.
- Preserve scroll position reasonably across refreshes.
- Export the rendered document to PDF.
- Provide a small command-line path for HTML output and PDF export.
- Use a minimal native AppKit shell and WKWebView rendering surface.
- Keep parser, source, style, presentation, and export responsibilities
  replaceable at genuine boundaries.

## Explicit non-goals for this phase

- Markdown editing.
- Neovim integration or Vim keybindings.
- Presentation/slides.
- Plugins or custom Markdown syntax.
- Theme-management UI.
- Project/workspace management.
- AI, collaboration, or cloud sync.

## Quality bar

Prefer fast launch, reliable refresh, readable typography, useful code blocks
and tables, predictable relative resources, matching preview/PDF output, clear
errors, and low complexity over feature count.
