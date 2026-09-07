import Foundation

public final class AppPreferences {
    public static let automaticallyShowsOpenPanelKey =
        "automaticallyShowsOpenPanelWhenNoDocumentsAreOpen"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var automaticallyShowsOpenPanelWhenNoDocumentsAreOpen: Bool {
        get {
            guard defaults.object(forKey: Self.automaticallyShowsOpenPanelKey) != nil else {
                return true
            }
            return defaults.bool(forKey: Self.automaticallyShowsOpenPanelKey)
        }
        set {
            defaults.set(newValue, forKey: Self.automaticallyShowsOpenPanelKey)
        }
    }
}
