//
//  OnboardingUITests.swift
//  Aesthelity
//
//  Created by Mia Carter on 10/13/26.
//


import XCTest

final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchFreshApp() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--pf01-ui-testing", "--pf01-reset-profile", "-resetStartupForUITests"]
        app.launch()
        return app
    }

    @MainActor
    func testFirstLaunchShowsWelcomeScreen() throws {
        let app = launchFreshApp()

        XCTAssertTrue(
            app.buttons["profile-get-started"].waitForExistence(timeout: 10),
            "The welcome screen should display the Get Started button."
        )
    }

    @MainActor
    func testGetStartedOpensSkinConcernsSetup() throws {
        let app = launchFreshApp()

        let getStartedButton = app.buttons["profile-get-started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 10))

        getStartedButton.tap()

        XCTAssertTrue(
            app.staticTexts["Your skin profile"]
                .waitForExistence(timeout: 5),
            "Get Started should open the skin concerns setup screen."
        )

        XCTAssertTrue(app.buttons["profile-continue"].exists)
    }

    @MainActor
    func testRepeatedGetStartedTapsDoNotCreateDuplicateScreens() throws {
        let app = launchFreshApp()

        let getStartedButton = app.buttons["profile-get-started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 10))

        // Two taps in one gesture, so the second always lands while the welcome screen is leaving.
        getStartedButton.doubleTap()

        let concernsTitle = app.staticTexts["Your skin profile"]

        XCTAssertTrue(
            concernsTitle.waitForExistence(timeout: 5),
            "The skin concerns setup screen should be displayed once."
        )
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "Your skin profile")).count,
            1,
            "Only one setup screen should be presented."
        )
        XCTAssertFalse(getStartedButton.exists)

        // A single Back must return to the welcome screen; a stacked duplicate would leave setup showing.
        app.buttons["Back"].tap()
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))
        XCTAssertTrue(concernsTitle.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testCompletedSetupUsesReturningUserRoute() throws {
        let app = launchFreshApp()

        let getStartedButton = app.buttons["profile-get-started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 10))
        getStartedButton.tap()

        let continueButton = app.buttons["profile-continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        XCTAssertTrue(
            app.staticTexts["Today's Routine"].waitForExistence(timeout: 10),
            "Continue should enter the app on Home."
        )

        app.terminate()
        app.launchArguments = ["--pf01-ui-testing"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Today's Routine"].waitForExistence(timeout: 10),
            "A returning user should land on Home."
        )
        XCTAssertFalse(
            app.buttons["profile-get-started"].exists,
            "A returning user should not see the welcome screen."
        )
    }
}
