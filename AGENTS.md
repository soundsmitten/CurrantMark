# CurrantMark agent instructions

## Mission

CurrantMark is a native macOS Markdown Browser. Keep it fast to understand,
fast to launch, and easy to replace at its real seams.
This file is the operating guide for agents and contributors. The `docs/`
directory is the deeper project record.

## Before changing code

1. Read this file and [docs/README.md](docs/README.md).
2. Read [docs/architecture.md](docs/architecture.md) for changes involving
   loading, parsing, rendering, WebKit, styling, or export.
3. Inspect the actual files and Git status. Do not infer repository truth from
   an old summary or generated project state.
4. Check [docs/implementation-status.md](docs/implementation-status.md) so a
   planned feature is not mistaken for an implemented one.

## Product boundaries

The current phase is a browser. Do not add editing, Neovim integration, Vim
keybindings, presentation mode, plugins, theme-management UI,
project/workspace management, AI, collaboration, or cloud sync unless the
user explicitly changes the scope.

## Architecture rules

- Keep file loading, file watching, Markdown processing, HTML generation,
  styling, WebKit presentation, and PDF export separate.
- Use `MarkdownProcessor` for the replaceable Markdown/rendering boundary.
  Never implement a second Markdown parser in the app.
- Preview and PDF export must consume the same `RenderedDocument` model.
- A document window may show one optional second preview pane, but both panes
  must consume the same document session. Different documents belong in
  different windows.
- Keep document sources abstract enough for future unsaved buffers or editor
  integrations, but do not create protocols for types with no real alternate
  implementation.
- Keep AppKit and WebKit code at the application edge. Reusable document and
  rendering code should not know about windows or menus.
- Prefer constructor injection and small focused protocols. Do not introduce a
  service locator, global mutable state, or singleton container.
- Commands belong to the application layer, but their underlying actions must
  remain reusable by future command-palette surfaces.
- Treat `Style.css` as a rendering input. Do not bury CSS strings in a view
  controller.

## Swift style

Follow the project adaptation of Kodeco and Airbnb Swift conventions in
[docs/style-guide.md](docs/style-guide.md). In particular:

- Prefer clear names, early exits with `guard`, small focused methods, and
  value types for data.
- Use explicit access control at public boundaries.
- Keep one primary responsibility per type and organize members predictably.
- Prefer dependency injection over hidden construction and global state.
- Do not optimize for clever brevity when a straightforward implementation is
  easier to review.
- Keep comments for intent, invariants, or non-obvious platform behavior; do
  not narrate obvious syntax.
- Avoid force unwraps and force casts in product code. If an invariant truly
  makes one necessary, document the invariant next to it.

## Documentation-as-you-go

Documentation is part of the implementation, not a cleanup task.

- Update `README.md` when setup, build, or contributor entry points change.
- Update `docs/architecture.md` when a component, data flow, or subsystem
  boundary changes.
- Update `docs/implementation-status.md` when a capability moves between
  planned, in progress, implemented, or known limitation.
- Add a numbered ADR under `docs/decisions/` for a durable architectural or
  dependency decision. Keep it short and record alternatives considered.
- If a task changes behavior but does not justify an ADR, add a concise note
  to the relevant document while making the code change.
- Never claim a build, test run, runtime behavior, or PDF result that was not
  actually verified.

## Validation

Use focused static checks by default: inspect the diff, `git diff --check`,
`plutil -lint` for property lists, `zsh -n` for shell scripts, and source
parsing or targeted tests when authorized. Do not run builds, app launches,
simulators, full test suites, package resolution, or long-running servers
unless the user explicitly asks for them.

## Handoff

Every handoff should state:

- what changed;
- which docs were updated;
- what was validated;
- what remains unverified or intentionally deferred; and
- whether Git was committed (never commit unless asked).
