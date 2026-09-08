import CurrantMarkCore
import Foundation
import XCTest

final class DocumentNavigationHistoryTests: XCTestCase {
    func testMovesBackwardAndForwardThroughVisitedDocuments() {
        var history = DocumentNavigationHistory()
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")

        history.visit(first, linkedFromCurrent: false)
        history.visit(second, linkedFromCurrent: true)

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

        history.visit(first, linkedFromCurrent: false)
        history.visit(second, linkedFromCurrent: true)
        _ = history.goBack()
        history.visit(replacement, linkedFromCurrent: true)

        XCTAssertFalse(history.canGoForward)
        XCTAssertEqual(history.goBack(), first)
    }

    func testBackReturnsToWhateverWasActuallyViewedEvenAfterOutOfOrderVisits() {
        // Regression test: Back/Forward must reflect the true chronological
        // order of navigation, not the position of a document in the
        // breadcrumb path. Visiting a document already in the path (e.g.
        // clicking an older breadcrumb segment) must still push a new
        // chronological entry rather than just repositioning a pointer.
        var history = DocumentNavigationHistory()
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")
        let third = URL(fileURLWithPath: "/tmp/third.md")

        history.visit(first, linkedFromCurrent: false)
        history.visit(second, linkedFromCurrent: true)
        history.visit(third, linkedFromCurrent: true)
        // Simulate clicking the breadcrumb segment for "first" out of
        // order, without going Back first.
        history.visit(first, linkedFromCurrent: false)

        // Back should return to "third" -- what was actually being viewed
        // immediately before the out-of-order jump -- not "second", which
        // would be the case if Back just walked breadcrumb array order.
        XCTAssertEqual(history.goBack(), third)
        XCTAssertEqual(history.goForward(), first)
    }

    func testRevisitingAnAncestorCollapsesTheBreadcrumbPathInstantOfGrowingIt() {
        var history = DocumentNavigationHistory()
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")
        let third = URL(fileURLWithPath: "/tmp/third.md")

        history.visit(first, linkedFromCurrent: false)
        history.visit(second, linkedFromCurrent: true)
        history.visit(third, linkedFromCurrent: true)
        // Following a link back to an ancestor should collapse the path
        // rather than appending a duplicate.
        history.visit(second, linkedFromCurrent: true)

        XCTAssertEqual(history.path, [first, second])
    }

    func testUnrelatedNavigationStartsAFreshBreadcrumbPath() {
        var history = DocumentNavigationHistory()
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")
        let unrelated = URL(fileURLWithPath: "/tmp/unrelated.md")

        history.visit(first, linkedFromCurrent: false)
        history.visit(second, linkedFromCurrent: true)
        // Opening a bookmark for a document with no relationship to the
        // current path should reset the breadcrumb, not graft onto it.
        history.visit(unrelated, linkedFromCurrent: false)

        XCTAssertEqual(history.path, [unrelated])
        // But the chronological stack still remembers what came before, so
        // Back still works.
        XCTAssertEqual(history.goBack(), second)
    }

    func testUnrelatedNavigationToAnExistingAncestorJumpsInsteadOfResetting() {
        var history = DocumentNavigationHistory()
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")

        history.visit(first, linkedFromCurrent: false)
        history.visit(second, linkedFromCurrent: true)
        // A bookmark pointing back at something already in the current
        // path is clearly related, so it should jump there, not reset.
        history.visit(first, linkedFromCurrent: false)

        XCTAssertEqual(history.path, [first])
    }

    func testRevisitingCurrentDocumentDoesNotDiscardItsBreadcrumbAncestry() {
        var history = DocumentNavigationHistory()
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")

        history.visit(first, linkedFromCurrent: false)
        history.visit(second, linkedFromCurrent: true)
        history.visit(second, linkedFromCurrent: false)

        XCTAssertEqual(history.path, [first, second])
    }
}
