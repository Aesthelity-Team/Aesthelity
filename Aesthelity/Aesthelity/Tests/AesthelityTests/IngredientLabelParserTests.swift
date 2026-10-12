//
//  IngredientLabelParserTests.swift
//  AesthelityTests
//
//  Created by Gaurav Pandey on 10/8/26.
//

import Testing
@testable import Aesthelity

struct IngredientLabelParserTests {
    @Test(arguments: [
        ("Water, Glycerin, Niacinamide",
         ["Water", "Glycerin", "Niacinamide"]),
        ("Ingredients: Aqua/Water/Eau, Glycerin, Alcohol Denat.",
         ["Aqua/Water/Eau", "Glycerin", "Alcohol Denat"]),
        ("Water (Aqua, Eau), 1,3-Butylene Glycol, Fragrance (Parfum)",
         ["Water (Aqua, Eau)", "1,3-Butylene Glycol", "Fragrance (Parfum)"]),
        ("Niacinamide 10%, Zinc PCA (1%), Salicylic Acid 2 %",
         ["Niacinamide", "Zinc PCA", "Salicylic Acid"]),
        ("Dimethicone, Mica. May Contain (+/-): CI 77891, CI 77491",
         ["Dimethicone", "Mica", "CI 77891", "CI 77491"]),
        ("Active Ingredients: Zinc Oxide 20%. Inactive Ingredients: Water; Glycerin",
         ["Zinc Oxide", "Water", "Glycerin"]),
        ("Aloe Barbadensis Leaf Juice*, Glycerin\nLinalool\n*Certified Organic",
         ["Aloe Barbadensis Leaf Juice", "Glycerin", "Linalool"]),
    ])
    func splitsLabelIntoNames(label: String, expected: [String]) {
        #expect(IngredientLabelParser.ingredientNames(in: label) == expected)
    }

    @Test(arguments: ["", "   ", " ,, ; \n "])
    func emptyLabelsHaveNoNames(label: String) {
        #expect(IngredientLabelParser.ingredientNames(in: label).isEmpty)
    }
}
