import Foundation

/// Editable form values. Raw text is retained until explicit submission processing.
struct ManualProductDraft: Equatable {
    var name: String = ""
    var brand: String = ""
    var category: DemoProductCategory?
    var rawIngredientList: String = ""
}
