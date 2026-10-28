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

final class ManualProductUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(reset: Bool = true, saveFailure: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--pd02-ui-testing"]
        if reset { app.launchArguments.append("--pd02-reset-products") }
        if saveFailure { app.launchArguments.append("--pd02-save-failure") }
        app.launch()
        XCTAssertTrue(app.buttons["tab.library"].waitForExistence(timeout: 10))
        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.buttons["manual-add"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func enter(_ name: String, ingredients: String, app: XCUIApplication) {
        app.buttons["manual-add"].tap()
        let field = app.textFields["manual-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        let label = app.textViews["manual-ingredients"]
        label.tap()
        label.typeText(ingredients)
        app.buttons["Done"].tap()
        reveal(app.buttons["manual-review"], in: app)
        app.buttons["manual-review"].tap()
    }

    @MainActor
    func testSaveWarningsAndRelaunch() {
        var app = launch()
        enter("Manual serum", ingredients: "Water, Niacinimide\nVitamin C, Unobtainium", app: app)
        let warning = app.staticTexts["manual-warning-1"]
        reveal(warning, in: app)
        XCTAssertTrue(warning.label.contains("Niacinamide"))
        let save = app.buttons["manual-save"]
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(app.buttons["manual-add"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Manual serum"].exists)
        app.terminate()
        app = launch(reset: false)
        XCTAssertTrue(app.staticTexts["Manual serum"].exists)
        app.staticTexts["Manual serum"].tap()
        XCTAssertTrue(app.navigationBars["Saved product"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Category not specified"].exists)
    }

    @MainActor
    func testRequiredAndInvalidInputRetainTextUntilCorrected() {
        let app = launch()
        app.buttons["manual-add"].tap()
        app.buttons["manual-review"].tap()
        XCTAssertTrue(app.staticTexts["manual-error-name"].exists)
        XCTAssertTrue(app.staticTexts["manual-error-ingredientList"].exists)
        XCTAssertFalse(app.buttons["manual-save"].exists)
        let name = app.textFields["manual-name"]
        name.tap()
        name.typeText("Invalid test")
        let ingredients = app.textViews["manual-ingredients"]
        ingredients.tap()
        ingredients.typeText("Water, !!!")
        app.buttons["Done"].tap()
        reveal(app.buttons["manual-review"], in: app)
        app.buttons["manual-review"].tap()
        XCTAssertTrue(app.staticTexts["manual-error-ingredientList"].label.contains("at least one letter"))
        XCTAssertEqual(ingredients.value as? String, "Water, !!!")
        ingredients.tap()
        ingredients.press(forDuration: 1.2)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
        } else {
            app.buttons["Select All"].tap()
        }
        ingredients.typeText("Water, Glycerin")
        XCTAssertEqual(ingredients.value as? String, "Water, Glycerin")
        app.buttons["Done"].tap()
        reveal(app.buttons["manual-review"], in: app)
        app.buttons["manual-review"].tap()
        reveal(app.buttons["manual-save"], in: app)
        app.buttons["manual-save"].tap()
        XCTAssertTrue(app.staticTexts["Invalid test"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCancelDoesNotSave() {
        let app = launch()
        enter("Discard me", ingredients: "Water", app: app)
        app.buttons["manual-cancel"].tap()
        XCTAssertTrue(app.buttons["manual-add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Discard me"].exists)
    }

    @MainActor
    func testSaveFailureRetainsReviewAndAllowsRetry() {
        let app = launch(saveFailure: true)
        enter("Retry me", ingredients: "Water", app: app)
        let save = app.buttons["manual-save"]
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(app.staticTexts["manual-save-error"].waitForExistence(timeout: 5))
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(app.staticTexts["manual-save-error"].exists)
        for _ in 0..<5 {
            if app.textFields["manual-name"].exists { break }
            app.collectionViews.firstMatch.swipeDown()
        }
        XCTAssertEqual(app.textFields["manual-name"].value as? String, "Retry me")
    }
}

final class RoutineEditorUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--pd02-ui-testing", "--pd02-reset-products"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = false) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            if upwards { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func create(in app: XCUIApplication) {
        reveal(app.buttons["routine-manage"], in: app)
        app.buttons["routine-manage"].tap()
        XCTAssertTrue(app.buttons["routine-create"].waitForExistence(timeout: 5))
        app.buttons["routine-create"].tap()
        XCTAssertTrue(app.textFields["routine-name"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func name(_ text: String, in app: XCUIApplication) {
        reveal(app.textFields["routine-name"], in: app, upwards: true)
        app.textFields["routine-name"].tap()
        app.textFields["routine-name"].typeText(text)
        app.keyboards.buttons["Done"].tap()
    }

    @MainActor
    private func pick(_ id: String, in app: XCUIApplication) {
        reveal(app.buttons["routine-add-product"], in: app)
        app.buttons["routine-add-product"].tap()
        let button = app.buttons["routine-pick-catalog-\(id)"]
        reveal(button, in: app)
        button.tap()
        XCTAssertTrue(app.buttons["routine-add-product"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCreateReorderConfirmRemovalSaveAndRejectEmptyEdit() {
        let app = launch()
        create(in: app)
        reveal(app.buttons["routine-save"], in: app)
        app.buttons["routine-save"].tap()
        XCTAssertTrue(app.staticTexts["routine-validation"].label.contains("routine name"))
        XCTAssertTrue(app.staticTexts["routine-validation"].label.contains("at least one product"))
        name("RT editor test", in: app)
        pick("cleanser_gel", in: app)
        pick("cleanser_oil", in: app)
        reveal(app.buttons["routine-down-0"], in: app, upwards: true)
        app.buttons["routine-down-0"].tap()
        XCTAssertTrue(app.staticTexts["routine-step-0"].label.contains("Demo Cleansing Oil"))
        reveal(app.buttons["routine-remove-1"], in: app)
        app.buttons["routine-remove-1"].tap()
        app.buttons["Keep product"].tap()
        XCTAssertTrue(app.staticTexts["routine-step-1"].exists)
        app.buttons["routine-remove-1"].tap()
        app.buttons["Remove product"].tap()
        XCTAssertFalse(app.staticTexts["routine-step-1"].exists)
        reveal(app.buttons["routine-save"], in: app)
        app.buttons["routine-save"].tap()
        let card = app.buttons["routine-card-RT editor test"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.staticTexts["routine-step-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["routine-step-0"].label.contains("Demo Cleansing Oil"))
        reveal(app.buttons["routine-remove-0"], in: app)
        app.buttons["routine-remove-0"].tap()
        app.buttons["Remove product"].tap()
        reveal(app.buttons["routine-save"], in: app)
        app.buttons["routine-save"].tap()
        XCTAssertTrue(app.staticTexts["routine-validation"].label.contains("at least one product"))
        reveal(app.buttons["Routines"], in: app, upwards: true)
        app.buttons["Routines"].tap()
        card.tap()
        XCTAssertTrue(app.staticTexts["routine-step-0"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testManualProductsRetainWarningsAndCancellingCreateDoesNotSave() {
        let app = launch()
        app.buttons["tab.library"].tap()
        app.buttons["manual-add"].tap()
        app.textFields["manual-name"].tap()
        app.textFields["manual-name"].typeText("Routine manual serum")
        app.textViews["manual-ingredients"].tap()
        app.textViews["manual-ingredients"].typeText("Water, Vitamin C")
        app.buttons["Done"].tap()
        reveal(app.buttons["manual-review"], in: app)
        app.buttons["manual-review"].tap()
        reveal(app.buttons["manual-save"], in: app)
        app.buttons["manual-save"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        app.buttons["tab.home"].tap()
        create(in: app)
        name("Cancelled routine", in: app)
        app.buttons["routine-add-product"].tap()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Routine manual serum")
        app.keyboards.buttons["Search"].tap()
        let manual = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "routine-pick-manual-")).firstMatch
        reveal(manual, in: app)
        manual.tap()
        XCTAssertTrue(app.staticTexts["routine-step-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["routine-step-0"].label.contains("Routine manual serum"))
        app.buttons["Ingredient details"].tap()
        let warning = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "could refer")).firstMatch
        reveal(warning, in: app)
        XCTAssertTrue(warning.exists)
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["routine-card-Cancelled routine"].exists)
    }
}
