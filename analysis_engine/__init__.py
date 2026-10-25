"""Rule-based product analysis primitives for Aesthelity."""

#lets other python files import the useful pieces from this modeule
from .product_input import (
    PreparedProductAnalysisInput,
    ProductInputError,
    UnresolvedIngredient,
    load_alias_catalog,
    prepare_analysis_input,
)

#need to name all the functions and data types this package will make available for other files
__all__ = [
    "PreparedProductAnalysisInput",
    "ProductInputError",
    "UnresolvedIngredient",
    "load_alias_catalog",
    "prepare_analysis_input",
]
