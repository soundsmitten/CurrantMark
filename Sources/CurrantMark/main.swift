import AppKit

// main.swift top-level code runs synchronously before any concurrency
// infrastructure starts, always on the main thread, so it is safe to assert
// main-actor isolation here even though top-level code itself is nonisolated.
let application = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }

application.setActivationPolicy(.regular)
application.delegate = delegate
application.mainMenu = MainActor.assumeIsolated { delegate.makeMainMenu() }
application.run()
