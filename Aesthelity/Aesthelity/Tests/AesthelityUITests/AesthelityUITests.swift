import XCTest

final class AesthelityUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchAppToHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--seed-routines")
        app.launch()

        // If onboarding appears, complete the sample setup flow.
        let getStarted = app.buttons["Get Started"]

        if getStarted.waitForExistence(timeout: 3) {
            getStarted.tap()

            let continueButton = app.buttons["Continue"]
            if continueButton.waitForExistence(timeout: 5) {
                continueButton.tap()
            }
        }

        return app
    }

    @MainActor
    private func openMyRoutines() -> XCUIApplication {
        let app = launchAppToHome()

        let manageRoutines = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Manage routines")
        ).firstMatch
        // The Manage routines row may be below the visible Home content.
        for _ in 0..<3 {
            if manageRoutines.exists {
                break
            }
            app.swipeUp()
        }

        XCTAssertTrue(
            manageRoutines.waitForExistence(timeout: 10),
            "The Manage routines button should be available on the Home screen."
        )

        manageRoutines.tap()

        XCTAssertTrue(
            app.staticTexts["My routines"].waitForExistence(timeout: 5)
        )

        return app
    }

    @MainActor
    func testSampleAMAndPMRoutinesAreDisplayed() throws {
        let app = openMyRoutines()

        XCTAssertTrue(app.staticTexts["AM Glow"].exists)
        XCTAssertTrue(app.staticTexts["PM Repair"].exists)
    }

    @MainActor
    func testAMRoutineDisplaysProductsInOrder() throws {
        let app = openMyRoutines()

        let amRoutine = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "AM Glow")
        ).firstMatch

        XCTAssertTrue(amRoutine.waitForExistence(timeout: 5))
        amRoutine.tap()

        let cleanser = app.staticTexts["Gentle Cleanser"]
        let vitaminC = app.staticTexts["Vitamin C Serum"]
        let moisturizer = app.staticTexts["Daily Moisturizer"]
        let sunscreen = app.staticTexts["SPF 46"]

        XCTAssertTrue(cleanser.waitForExistence(timeout: 5))
        XCTAssertTrue(vitaminC.exists)
        XCTAssertTrue(moisturizer.exists)
        XCTAssertTrue(sunscreen.exists)

        XCTAssertLessThan(cleanser.frame.minY, vitaminC.frame.minY)
        XCTAssertLessThan(vitaminC.frame.minY, moisturizer.frame.minY)
        XCTAssertLessThan(moisturizer.frame.minY, sunscreen.frame.minY)
    }

    @MainActor
    func testPMRoutineDisplaysProductsInOrder() throws {
        let app = openMyRoutines()

        let pmRoutine = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "PM Repair")
        ).firstMatch

        XCTAssertTrue(pmRoutine.waitForExistence(timeout: 5))
        pmRoutine.tap()

        let preCleanse = app.staticTexts["Micellar Pre-Cleanse"]
        let foamingWash = app.staticTexts["Gentle Foaming Wash"]
        let hyaluronicAcid = app.staticTexts["Hyaluronic Acid"]
        let nightCream = app.staticTexts["Barrier Night Cream"]
        let lipMask = app.staticTexts["Lip Sleep Mask"]

        XCTAssertTrue(preCleanse.waitForExistence(timeout: 5))
        XCTAssertTrue(foamingWash.exists)
        XCTAssertTrue(hyaluronicAcid.exists)
        XCTAssertTrue(nightCream.exists)
        XCTAssertTrue(lipMask.exists)

        XCTAssertLessThan(preCleanse.frame.minY, foamingWash.frame.minY)
        XCTAssertLessThan(foamingWash.frame.minY, hyaluronicAcid.frame.minY)
        XCTAssertLessThan(hyaluronicAcid.frame.minY, nightCream.frame.minY)
        XCTAssertLessThan(nightCream.frame.minY, lipMask.frame.minY)
    }

    @MainActor
    func testRoutineEmptyStateIsDisplayed() throws {
        let app = openMyRoutines()

        let emptyButton = app.buttons["Empty"]
        XCTAssertTrue(emptyButton.waitForExistence(timeout: 5))
        emptyButton.tap()

        XCTAssertTrue(
            app.staticTexts["No routines yet"].waitForExistence(timeout: 5)
        )

        XCTAssertTrue(app.buttons["Create routine"].exists)
    }

}
