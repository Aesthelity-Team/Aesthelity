import XCTest

/// Offline acceptance journeys. The backend contract is covered by loopback HTTP tests;
/// authenticated HTTPS result verification is recorded in docs/QA02.md.
final class IntegrationJourneyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = false) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            if upwards { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, "Expected to reach \(element)")
    }

    @MainActor
    private func launchFresh() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--pf01-ui-testing", "--pf01-reset-profile",
                               "--rt02-ui-testing", "--reset-routines"]
        app.launch()
        XCTAssertTrue(app.buttons["profile-get-started"].waitForExistence(timeout: 10))
        app.buttons["profile-get-started"].tap()
        XCTAssertTrue(app.buttons["profile-continue"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func finishProfile(_ app: XCUIApplication, skipped: Bool) {
        app.buttons["skin-type-dry"].tap()
        let concern = app.buttons["concern-barrier-repair"]
        reveal(concern, in: app)
        concern.tap()
        let finish = app.buttons[skipped ? "profile-skip" : "profile-continue"]
        reveal(finish, in: app, upwards: true)
        finish.tap()
        XCTAssertTrue(app.staticTexts["Today's Routine"].waitForExistence(timeout: 10))
        assertProfile(app, skipped: skipped)
        app.buttons["tab.home"].tap()
    }

    @MainActor
    private func assertProfile(_ app: XCUIApplication, skipped: Bool) {
        app.buttons["profile-tab"].tap()
        let status = app.staticTexts["profile-summary-status"]
        reveal(status, in: app, upwards: true)
        XCTAssertEqual(status.label, skipped ? "Profile incomplete — setup skipped" : "Profile setup completed")
        XCTAssertEqual(app.staticTexts["profile-summary-skin-type"].label, skipped ? "Not provided" : "Dry")
        XCTAssertEqual(app.staticTexts["profile-summary-concerns"].label, skipped ? "None provided" : "Barrier repair")
    }

    @MainActor
    private func createRoutine(_ app: XCUIApplication, name: String, partial: Bool = false) {
        let create = app.buttons["home.createRoutine"]
        reveal(create, in: app, upwards: true)
        create.tap()
        let nameField = app.textFields["routine-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        let existingName = nameField.value as? String ?? ""
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingName.count))
        nameField.typeText(name + "\n")
        let products = partial
            ? [("cleanser_gel", "Gentle Gel Cleanser"), ("mask_partial", "Incomplete Mask Demo")]
            : [("serum_retinol", "Retinol Night Serum"), ("treatment_exfoliant", "Exfoliating Treatment")]
        for (id, query) in products {
            let add = app.buttons["routine-add-product"]
            reveal(add, in: app)
            add.tap()
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            search.typeText(query + "\n")
            let product = app.buttons["routine-pick-catalog-\(id)"]
            XCTAssertTrue(product.waitForExistence(timeout: 5))
            reveal(product, in: app)
            product.tap()
            XCTAssertTrue(add.waitForExistence(timeout: 5))
        }
        let save = app.buttons["routine-save"]
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(app.staticTexts["Today's Routine"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.editRoutine"].exists)
    }

    @MainActor
    private func verifyAnalysisAndRetry(_ app: XCUIApplication, name: String, partial: Bool) {
        let analysis = app.buttons[">> View analysis"]
        reveal(analysis, in: app)
        analysis.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        let screen = app.scrollViews["routine-analysis-scroll"]
        XCTAssertTrue(screen.waitForExistence(timeout: 5))
        let order = screen.staticTexts[partial ? "Layering order is uncertain" : "Suggested layering order"].firstMatch
        reveal(order, in: app)
        XCTAssertTrue(order.exists)
        let firstProduct = partial ? "1. Gentle Gel Cleanser (Fictional)" : "1. Retinol Night Serum (Fictional)"
        XCTAssertTrue(screen.staticTexts[firstProduct].firstMatch.exists)
        let run = app.buttons["run-personal-analysis"]
        reveal(run, in: app)
        for _ in 0..<2 {
            run.tap()
            let message = app.staticTexts["personal-analysis-message"]
            XCTAssertTrue(message.waitForExistence(timeout: 10))
            XCTAssertTrue([
                "A secure backend connection has not been configured.",
                "Your session could not be verified. Please sign in again."
            ].contains(message.label), message.label)
            XCTAssertTrue(run.isEnabled)
            XCTAssertFalse(app.staticTexts["No recorded conflicts"].exists)
            XCTAssertFalse(app.otherElements["personal-analysis-result"].exists)
        }
        capture("Analysis failure preserves \(name)", app: app)
        app.buttons["Back"].firstMatch.tap()
    }

    @MainActor
    private func verifyRelaunch(_ app: XCUIApplication, name: String, skipped: Bool) {
        app.terminate()
        app.launchArguments = ["--pf01-ui-testing", "--rt02-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Today's Routine"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["profile-get-started"].exists)
        assertProfile(app, skipped: skipped)
        app.buttons["tab.home"].tap()
        let edit = app.buttons["home.editRoutine"]
        reveal(edit, in: app, upwards: true)
        edit.tap()
        XCTAssertEqual(app.textFields["routine-name"].value as? String, name)
        XCTAssertTrue(app.staticTexts["routine-step-0"].label.contains(
            skipped ? "Gentle Gel Cleanser" : "Retinol Night Serum"
        ))
        XCTAssertTrue(app.staticTexts["routine-step-1"].label.contains(
            skipped ? "Incomplete Mask Demo" : "Exfoliating Treatment"
        ))
        capture("Persisted \(name)", app: app)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCompletedProfileRoutineAnalysisRetryAndRelaunch() {
        let app = launchFresh()
        finishProfile(app, skipped: false)
        createRoutine(app, name: "QA completed journey")
        verifyAnalysisAndRetry(app, name: "QA completed journey", partial: false)
        verifyRelaunch(app, name: "QA completed journey", skipped: false)
    }

    @MainActor
    func testSkippedProfilePartialRoutineAnalysisRetryAndRelaunch() {
        let app = launchFresh()
        finishProfile(app, skipped: true)
        createRoutine(app, name: "QA skipped journey", partial: true)
        verifyAnalysisAndRetry(app, name: "QA skipped journey", partial: true)
        verifyRelaunch(app, name: "QA skipped journey", skipped: true)
    }
}
