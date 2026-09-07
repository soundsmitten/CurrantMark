import CurrantMarkCore
import Foundation
import XCTest

final class DocumentNavigationHistoryTests: XCTestCase {
    func testMovesBackwardAndForwardThroughVisitedDocuments() {
        var history = DocumentNavigationHistory()
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")

        history.visit(first)
        history.visit(second)

        XCTAssertTrue(history.hasNavigated)
        XCTAssertTrue(history.canGoBack)
        XCTAssertEqual(history.goBack(), first)
        XCTAssertTrue(history.canGoForward)
        XCTAssertEqual(history.goForward(), second)
    }

    func testVisitingAfterGoingBackDiscardsForwardHistory() {
        var history = DocumentNavigationHistory()
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")
        let replacement = URL(fileURLWithPath: "/tmp/replacement.md")

        history.visit(first)
        history.visit(second)
        _ = history.goBack()
        history.visit(replacement)

        XCTAssertFalse(history.canGoForward)
        XCTAssertEqual(history.goBack(), first)
    }

    func testMovingToHistoryItemSelectsItWithoutRemovingOtherItems() {
        var history = DocumentNavigationHistory()
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")
        let third = URL(fileURLWithPath: "/tmp/third.md")
        history.visit(first)
        history.visit(second)
        history.visit(third)

        XCTAssertEqual(history.move(to: 0), first)
        XCTAssertEqual(history.selectedIndex, 0)
        XCTAssertEqual(history.items, [first, second, third])
        XCTAssertTrue(history.canGoForward)
    }

    func testMovingToInvalidHistoryItemDoesNothing() {
        var history = DocumentNavigationHistory()
        let document = URL(fileURLWithPath: "/tmp/document.md")
        history.visit(document)

        XCTAssertNil(history.move(to: 9))
        XCTAssertEqual(history.selectedIndex, 0)
    }
}
