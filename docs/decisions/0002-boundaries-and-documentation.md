# ADR 0002: Strong seams, small architecture

- Status: accepted
- Date: 2026-09-07

## Context

The app may eventually support alternate Markdown engines, unsaved editor
buffers, styles, export options, command-palette surfaces, and presentation.
Predicting every feature would make the first version harder to understand.

## Decision

Keep only four replaceable boundaries today: `DocumentSource`,
`MarkdownProcessor`, `RenderedDocument`, and `PDFExporter`. Keep AppKit/WebKit
presentation and command wiring concrete until a real second implementation
requires another boundary.

Treat documentation as part of the architecture: `AGENTS.md` gives agents the
operating rules, `docs/` records current behavior and scope, and ADRs record
durable decisions.

## Consequences

- New implementations can be introduced without rewriting the main flow.
- The code remains small enough for a new contributor to trace in one sitting.
- Some future features will require intentionally adding a seam later.
- Agents must update documentation in the same change when behavior or
  architecture changes.
