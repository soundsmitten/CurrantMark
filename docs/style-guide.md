# Swift style guide

CurrantMark follows the official Kodeco Swift style guide and Airbnb’s Swift
style guide where they agree, with the project’s readability and small-scope
needs taking precedence over mechanical ceremony.

References:

- [Kodeco Swift Style Guide](https://github.com/kodecocodes/swift-style-guide)
- [Airbnb Swift Style Guide](https://swift.airbnb.tech/)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)

## Project rules

### Naming and API shape

- Use descriptive lowerCamelCase for values and UpperCamelCase for types.
- Prefer names that read naturally at the call site.
- Use argument labels to clarify meaning rather than encoding type names in
  identifiers.
- Keep public APIs small and document the reason for a public boundary when it
  is not self-evident.

### Control flow

- Prefer `guard` for required preconditions and early exits.
- Keep happy paths at the main indentation level.
- Avoid deeply nested closures and conditionals; extract a named method when
  the behavior has a concept of its own.
- Prefer `if let`/`guard let` and optional modeling over force unwraps.

### Types and dependencies

- Prefer structs and enums for data and classes only when identity or platform
  lifecycle matters.
- Use protocols at actual replacement or platform boundaries, not for every
  concrete type.
- Inject dependencies through initializers when a type has a meaningful
  collaborator.
- Avoid global mutable state, hidden singletons, and service locators.

### Files and organization

- Keep one primary responsibility per file.
- Group related declarations and keep member order predictable: nested types,
  stored properties, initialization, lifecycle, public API, private helpers.
- Keep UIKit/AppKit/WebKit imports and code in platform-facing files.
- Keep comments focused on intent, invariants, and non-obvious framework
  behavior.

### Formatting and review

- Use four-space indentation and standard Swift formatting.
- Keep lines readable; split long expressions at meaningful boundaries.
- Prefer clarity over clever one-liners.
- Review diffs for unrelated formatting churn.
- A formatter or linter may be added later, but tooling must not obscure the
  code or add a large dependency footprint.
