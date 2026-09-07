# Product scope

## Current goal

CurrantMark should be a small daily-use native macOS Markdown viewer: open a
Markdown file, render it cleanly, refresh when it changes, preserve the reader’s
place, and export the rendered result to PDF.

## Current requirements

- Open Markdown files through a standard Open panel.
- Open Markdown files from Finder.
- Open each document in its own native window.
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
