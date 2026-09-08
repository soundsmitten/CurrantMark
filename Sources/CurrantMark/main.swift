import AppKit

// AppKit enters through the process main thread. Keep setup and the blocking
// application run loop in one actor-isolated scope so AppKit objects never
// cross the isolation boundary.
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()

    application.setActivationPolicy(.regular)
    application.delegate = delegate
    application.mainMenu = delegate.makeMainMenu()
    application.run()
}
