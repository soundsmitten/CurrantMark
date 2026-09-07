# Contributing

## Small change loop

1. Read `AGENTS.md`, this directory’s index, and the architecture document
   relevant to the change.
2. Inspect the repository root and Git status.
3. Make the smallest coherent change.
4. Add or update focused tests when behavior is independently testable.
5. Update the relevant documentation in the same change.
6. Run only the validation authorized for the task.
7. Report what changed, what was validated, and what remains unverified.

## When to add an ADR

Add a short decision record when choosing or replacing a dependency, changing a
subsystem boundary, changing the document or rendering model, changing the
packaging strategy, or making a decision that a future contributor would
otherwise need to reconstruct from history.

An ADR should include context, the decision, consequences, and alternatives
considered. Do not use ADRs for ordinary bug fixes or local refactors.

## Tests

Prefer tests that do not need a window or running app: Markdown-to-HTML
behavior, style injection, source loading, watcher policies, and export model
inputs. UI and WKWebView tests should be added only when they protect behavior
that cannot be tested at a lower boundary.

## Pull requests and handoffs

Describe the user-visible result first. Include a short architecture note when
the change crosses a boundary. Do not claim runtime, build, PDF, or simulator
validation unless it was actually performed.
