import XCTest

/// Sprint 1 demo flows that cross onboarding (ON-01), profile setup (PF-01),
/// tabs (UI-01), Home routines (RT-01), and the mocked analysis (AN-01).
final class Sprint1DemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @MainActor
    private func launchFreshApp() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--pf01-ui-testing", "--pf01-reset-profile"]
        app.launch()
        XCTAssertTrue(app.buttons["profile-get-started"].waitForExistence(timeout: 10), "A fresh launch should show the welcome screen.")
        return app
    }

    @MainActor
    private func assertOnHome(_ app: XCUIApplication, _ message: String = "The app should show Home.") {
        XCTAssertTrue(app.staticTexts["Today's Routine"].waitForExistence(timeout: 10), message)
    }

    @MainActor
    private func enterWithoutSetup() -> XCUIApplication {
        let app = launchFreshApp()
        app.buttons["Explore without an account"].tap()
        assertOnHome(app)
        return app
    }

    @MainActor
    private func openProfile(_ app: XCUIApplication) {
        app.buttons["profile-tab"].tap()
        XCTAssertTrue(app.staticTexts["Skin Profile"].waitForExistence(timeout: 5), "The Profile tab should show the skin profile.")
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Skin Type"].waitForExistence(timeout: 5), "Settings should show the skin profile rows.")
    }

    @MainActor
    private func text(_ app: XCUIApplication, _ value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", value)).firstMatch
    }

    @MainActor
    private func button(_ app: XCUIApplication, containing value: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    /// Swipes up until the element is on screen. Fails if it never becomes hittable.
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "\(element) should be reachable by scrolling.")
    }

    // MARK: - Tabs

    @MainActor
    func testAllFiveTabsAreReachable() throws {
        let app = enterWithoutSetup()

        let destinations: [(tab: String, marker: String)] = [
            ("tab.library", "Products organized by relationship."),
            ("tab.scan", "Analyze products instantly."),
            ("tab.explore", "Learn skincare science and routine basics."),
            ("profile-tab", "Skin Profile"),
            ("tab.home", "Today's Routine")
        ]

        for destination in destinations {
            let tab = app.buttons[destination.tab]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(destination.tab) should be in the tab bar.")
            tab.tap()
            XCTAssertTrue(
                text(app, destination.marker).waitForExistence(timeout: 5),
                "\(destination.tab) should open the screen showing \"\(destination.marker)\"."
            )
        }
    }

    // MARK: - Home routines and analysis

    @MainActor
    func testHomeSwitchesBetweenAMAndPMRoutines() throws {
        let app = enterWithoutSetup()

        XCTAssertTrue(text(app, "SPF 46").waitForExistence(timeout: 5), "Home should open on the AM routine.")

        app.buttons["PM"].tap()
        let pmOrder = ["Oil Cleanser", "Niacinamide Serum", "Night Recovery Cream", "Hydrating Eye Balm"].map { text(app, $0) }
        XCTAssertTrue(pmOrder[0].waitForExistence(timeout: 5), "PM should show the PM routine.")
        XCTAssertTrue(text(app, "SPF 46").waitForNonExistence(timeout: 5), "PM should not show AM steps.")
        for element in pmOrder {
            XCTAssertTrue(element.exists)
        }
        for (earlier, later) in zip(pmOrder, pmOrder.dropFirst()) {
            XCTAssertLessThan(earlier.frame.minY, later.frame.minY, "PM steps should appear in application order.")
        }
        XCTAssertTrue(text(app, "Pending · Step 5").exists, "PM steps should show their status and step number.")

        app.buttons["AM"].tap()
        XCTAssertTrue(text(app, "SPF 46").waitForExistence(timeout: 5), "AM should show the AM routine again.")
        XCTAssertFalse(text(app, "Hydrating Eye Balm").exists)
    }

    @MainActor
    func testMockedAnalysisIsReachableFromHome() throws {
        let app = enterWithoutSetup()

        let viewAnalysis = app.buttons[">> View analysis"]
        scrollTo(viewAnalysis, in: app)
        viewAnalysis.tap()

        let sampleFindings = text(app, "Sample Findings")
        XCTAssertTrue(sampleFindings.waitForExistence(timeout: 5), "The analysis screen should show the sample findings.")

        let caution = app.buttons["Caution"]
        scrollTo(caution, in: app)
        caution.tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Retinol Night Serum")).firstMatch.waitForExistence(timeout: 5),
            "The caution sample should name the affected product."
        )
        XCTAssertTrue(text(app, "Why this finding was generated").exists, "The caution sample should explain why it was generated.")

        app.buttons["Back"].firstMatch.tap()
        assertOnHome(app, "Back should return to Home.")
    }
}
