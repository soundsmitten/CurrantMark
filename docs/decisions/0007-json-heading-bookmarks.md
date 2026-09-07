# 0007: Persist heading bookmarks as versioned JSON

## Status

Accepted.

## Context

Bookmarks need to appear consistently in document gutters, the main menu, and
an app-wide management window. They are structured user data rather than a
preference, but the initial feature does not need a relational database.
Arbitrary pixel offsets would become invalid whenever a Markdown file changes.

## Decision

Store a versioned `BookmarkLibrary` in
`Application Support/CurrantMark/Bookmarks.json` through `BookmarkStore`.
Writes are atomic. A bookmark records its document URL, generated heading
anchor, heading text excerpt, creation date, and security-scoped bookmark data
when available.

`BookmarkController` owns bookmark commands and supplies one shared library to
the gutter, Bookmarks menu, and Bookmarks window. The initial UI only bookmarks
headings because the Markdown processor already gives them stable anchors.

## Alternatives considered

- `UserDefaults`: rejected because bookmarks are user content, not settings.
- Core Data or SwiftData: deferred because the current data and queries are
  small and do not justify a database or migration framework.
- Scroll offsets: rejected because edits make them unreliable.

## Consequences

Persistence remains inspectable and replaceable without affecting UI actions.
Heading renames can invalidate an anchor; the retained excerpt provides a seam
for future recovery, but recovery is not implemented in this phase.
