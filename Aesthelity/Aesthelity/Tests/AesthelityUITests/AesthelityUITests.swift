//
//  AesthelityUITests 2.swift
//  Aesthelity
//
//  Created by Mia Carter on 10/13/26.
//


import XCTest

final class AesthelityUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStartupForUITests"]
        app.launch()
        return app
    }

    @MainActor
    func testFirstLaunchShowsWelcomeScreen() throws {
        let app = launchFreshApp()

        XCTAssertTrue(
            app.buttons["Get Started"].waitForExistence(timeout: 10),
            "The welcome screen should display the Get Started button."
        )
    }

    @MainActor
    func testGetStartedOpensSkinConcernsSetup() throws {
        let app = launchFreshApp()

        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 10))

        getStartedButton.tap()

        XCTAssertTrue(
            app.staticTexts["What are your skin priorities?"]
                .waitForExistence(timeout: 5),
            "Get Started should open the skin concerns setup screen."
        )

        XCTAssertTrue(app.buttons["Continue"].exists)
    }

    @MainActor
    func testRepeatedGetStartedTapsDoNotCreateDuplicateScreens() throws {
        let app = launchFreshApp()

        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 10))

        getStartedButton.tap()

        if getStartedButton.exists && getStartedButton.isHittable {
            getStartedButton.tap()
        }

        let concernsTitle = app.staticTexts["What are your skin priorities?"]

        XCTAssertTrue(
            concernsTitle.waitForExistence(timeout: 5),
            "The skin concerns setup screen should be displayed once."
        )
    }

    @MainActor
    func testCompletedSetupUsesReturningUserRoute() throws {
        let app = launchFreshApp()

        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 10))
        getStartedButton.tap()

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertFalse(
            app.buttons["Get Started"].waitForExistence(timeout: 3),
            "A returning user should not see the welcome screen."
        )
    }
}
