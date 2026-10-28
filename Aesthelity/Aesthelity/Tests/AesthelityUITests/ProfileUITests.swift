import XCTest

final class ProfileUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchFresh() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--pf01-ui-testing", "--pf01-reset-profile"]
        app.launch()
        XCTAssertTrue(app.buttons["profile-get-started"].waitForExistence(timeout: 10))
        app.buttons["profile-get-started"].tap()
        XCTAssertTrue(app.buttons["profile-continue"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            let setup = app.scrollViews["profile-setup-scroll"]
            let scroll = setup.exists ? setup : app.scrollViews["profile-summary-scroll"]
            scroll.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Expected element to be visible: \(element)")
    }

    @MainActor
    private func addIngredient(_ text: String, index: Int, in app: XCUIApplication) {
        let add = app.buttons["add-ingredient"]
        reveal(add, in: app)
        add.tap()
        let field = app.textFields["ingredient-input-\(index)"]
        reveal(field, in: app)
        field.tap()
        field.typeText(text + "\n")
    }

    @MainActor
    private func openProfile(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["profile-tab"].waitForExistence(timeout: 5))
        app.buttons["profile-tab"].tap()
        reveal(app.staticTexts["profile-summary-status"], in: app)
    }

    @MainActor
    private func relaunch(_ app: XCUIApplication) {
        app.terminate()
        app.launchArguments = ["--pf01-ui-testing"]
        app.launch()
        XCTAssertFalse(app.buttons["profile-get-started"].exists)
        openProfile(in: app)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCompleteProfileSuggestionsSummaryAndRelaunch() throws {
        let app = launchFresh()
        for type in ["normal", "dry", "oily", "combination"] {
            XCTAssertFalse(app.buttons["skin-type-\(type)"].isSelected)
        }
        XCTAssertFalse(app.buttons["concern-barrier-repair"].isSelected)
        app.buttons["skin-type-dry"].tap()
        reveal(app.buttons["concern-barrier-repair"], in: app)
        app.buttons["concern-barrier-repair"].tap()
        addIngredient("Parfum", index: 0, in: app)
        addIngredient("Niacinimide", index: 1, in: app)
        let suggestion = app.buttons["ingredient-suggestion-1-niacinamide"]
        reveal(suggestion, in: app)
        XCTAssertTrue(app.staticTexts["ingredient-warning-1"].exists)
        suggestion.tap()
        XCTAssertEqual(app.textFields["ingredient-input-1"].value as? String, "Niacinamide")
        addIngredient("Vitamin C", index: 2, in: app)
        reveal(app.staticTexts["ingredient-warning-2"], in: app)
        XCTAssertTrue(app.staticTexts["ingredient-warning-2"].label.contains("could refer"))
        capture("Setup with unresolved ingredient", app: app)
        app.buttons["profile-continue"].tap()
        openProfile(in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-status"].label, "Profile setup completed")
        XCTAssertEqual(app.staticTexts["profile-summary-skin-type"].label, "Dry")
        reveal(app.staticTexts["profile-summary-concerns"], in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-concerns"].label, "Barrier repair")
        reveal(app.staticTexts["profile-summary-ingredient-2"], in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-0"].label, "Fragrance")
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-1"].label, "Niacinamide")
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-2"].label, "Vitamin C")
        capture("Completed profile summary", app: app)
        relaunch(app)
        XCTAssertEqual(app.staticTexts["profile-summary-skin-type"].label, "Dry")
        reveal(app.staticTexts["profile-summary-ingredient-2"], in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-2"].label, "Vitamin C")
        let edit = app.buttons["edit-skin-profile"]
        reveal(edit, in: app)
        edit.tap()
        XCTAssertTrue(app.buttons["profile-continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["skin-type-dry"].isSelected)
        reveal(app.buttons["concern-barrier-repair"], in: app)
        XCTAssertTrue(app.buttons["concern-barrier-repair"].isSelected)
        app.buttons["skin-type-oily"].tap()
        app.buttons["Back"].tap()
        relaunch(app)
        XCTAssertEqual(app.staticTexts["profile-summary-skin-type"].label, "Dry")
    }

    @MainActor
    func testSkippedDraftRemainsIncompleteAfterRelaunch() throws {
        let app = launchFresh()
        app.buttons["skin-type-oily"].tap()
        addIngredient("Retinol", index: 0, in: app)
        app.buttons["profile-skip"].tap()
        openProfile(in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-status"].label, "Profile incomplete — setup skipped")
        XCTAssertEqual(app.staticTexts["profile-summary-skin-type"].label, "Not provided")
        reveal(app.staticTexts["profile-summary-ingredients"], in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-ingredients"].label, "None provided")
        capture("Skipped profile summary", app: app)
        relaunch(app)
        XCTAssertEqual(app.staticTexts["profile-summary-status"].label, "Profile incomplete — setup skipped")
    }

    @MainActor
    func testInvalidInputIsRetainedAndCanBeCorrected() throws {
        let app = launchFresh()
        addIngredient("!!!", index: 0, in: app)
        app.buttons["profile-continue"].tap()
        let error = app.staticTexts["ingredient-error-0"]
        reveal(error, in: app)
        XCTAssertEqual(error.label, "An ingredient name must contain at least one letter.")
        XCTAssertEqual(app.textFields["ingredient-input-0"].value as? String, "!!!")
        XCTAssertFalse(app.buttons["profile-tab"].exists)
        XCTAssertTrue(app.buttons["profile-continue"].isHittable)
        capture("Inline validation retains input", app: app)
        let field = app.textFields["ingredient-input-0"]
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "Parfum\n")
        XCTAssertFalse(error.exists)
        addIngredient("", index: 1, in: app)
        app.buttons["profile-continue"].tap()
        reveal(app.staticTexts["ingredient-error-1"], in: app)
        XCTAssertTrue(app.staticTexts["ingredient-error-1"].exists)
        app.buttons["Remove ingredient 2"].tap()
        app.buttons["profile-continue"].tap()
        openProfile(in: app)
        reveal(app.staticTexts["profile-summary-ingredient-0"], in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-0"].label, "Fragrance")
    }

    @MainActor
    func testAliasUnknownAndAmbiguousEntriesStayDistinct() throws {
        let app = launchFresh()
        let entries = [
            ("Aqua", "Recognized as Water"),
            ("Glycerol", "Recognized as Glycerin"),
            ("Nicotinamide", "Recognized as Niacinamide")
        ]
        for (index, entry) in entries.enumerated() {
            addIngredient(entry.0, index: index, in: app)
            let match = app.staticTexts["ingredient-match-\(index)"]
            reveal(match, in: app)
            XCTAssertEqual(match.label, entry.1)
        }
        addIngredient("Unobtainium Extract", index: 3, in: app)
        let unknown = app.staticTexts["ingredient-warning-3"]
        reveal(unknown, in: app)
        XCTAssertTrue(unknown.label.contains("does not match"))
        addIngredient("Vitamin C", index: 4, in: app)
        let ambiguous = app.staticTexts["ingredient-warning-4"]
        reveal(ambiguous, in: app)
        XCTAssertTrue(ambiguous.label.contains("could refer"))
        addIngredient("Niacinimide", index: 5, in: app)
        let suggestion = app.buttons["ingredient-suggestion-5-niacinamide"]
        reveal(suggestion, in: app)
        XCTAssertTrue(app.staticTexts["ingredient-warning-5"].exists)
        XCTAssertNotEqual(app.textFields["ingredient-input-5"].value as? String, "Niacinamide")

        app.buttons["profile-continue"].tap()
        openProfile(in: app)
        reveal(app.staticTexts["profile-summary-ingredient-5"], in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-0"].label, "Water")
        XCTAssertEqual(app.staticTexts["profile-summary-original-0"].label, "Entered as Aqua")
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-1"].label, "Glycerin")
        XCTAssertEqual(app.staticTexts["profile-summary-original-1"].label, "Entered as Glycerol")
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-2"].label, "Niacinamide")
        XCTAssertEqual(app.staticTexts["profile-summary-original-2"].label, "Entered as Nicotinamide")
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-3"].label, "Unobtainium Extract")
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-4"].label, "Vitamin C")
        XCTAssertEqual(app.staticTexts["profile-summary-ingredient-5"].label, "Niacinimide")
        XCTAssertFalse(app.staticTexts["profile-summary-original-5"].exists)
    }

    @MainActor
    func testEmptyOptionalProfileCompletesWithoutInventingChoices() throws {
        let app = launchFresh()
        app.buttons["profile-continue"].tap()
        openProfile(in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-status"].label, "Profile setup completed")
        XCTAssertEqual(app.staticTexts["profile-summary-skin-type"].label, "Not provided")
        reveal(app.staticTexts["profile-summary-concerns"], in: app)
        XCTAssertEqual(app.staticTexts["profile-summary-concerns"].label, "None provided")
    }

    @MainActor
    func testExample() throws {
        XCUIApplication().launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
