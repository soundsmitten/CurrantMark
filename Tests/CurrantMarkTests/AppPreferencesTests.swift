import CurrantMarkCore
import Foundation
import XCTest

final class AppPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AppPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testAutomaticallyShowsOpenPanelByDefault() {
        let preferences = AppPreferences(defaults: defaults)

        XCTAssertTrue(preferences.automaticallyShowsOpenPanelWhenNoDocumentsAreOpen)
    }

    func testPersistsDisabledOpenPanelPreference() {
        let preferences = AppPreferences(defaults: defaults)

        preferences.automaticallyShowsOpenPanelWhenNoDocumentsAreOpen = false

        let reloadedPreferences = AppPreferences(defaults: defaults)
        XCTAssertFalse(reloadedPreferences.automaticallyShowsOpenPanelWhenNoDocumentsAreOpen)
    }
}
