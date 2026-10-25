#Preparing product data for rule analysis (true analysis will be implemented once we all agree on the rules)

from __future__ import annotations

import json
import re #using to check format of ingredient IDs
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping


_CANONICAL_ID = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
"""
accepted format for each identified ingredients canonical ID
"""

_LIST_STATUSES = {"complete", "partial", "unavailable"}
"""
Accepted list statuses labels. 
List status is about whole ingredient list.
- complete = the products full ingredient list is available
- partial = only some of the list is available
- unavailable = the list is not available
"""

_MAPPINGS = {"confirmed", "uncertain", "ambiguous", "unmatched"} 
"""
Accepted mappings labels.
mappings is about one specific ingredient row.
- confirmed = it has a cononical ID
- Uncertain, ambiguous, and unmatched = canonical ID isnt confirmed
"""


class ProductInputError(ValueError):
    """
    We'll use this as a custom error for product records. Reports when the product record or catalog contains any invalid data. For 
    exmaple, if an ingredients list isnt the correct type (should be type list).
    """


@dataclass(frozen=True)
class UnresolvedIngredient:
    """
    Creates a data entry row for an unconfirmed products due to unmatched ingredient with corresponding
    attributes including its original text, current mapping label, why it is marked as unresolved, and
    suggested candidate IDs 
    """

    original_text: str
    mapping: str
    reason: str #reason why this ingredient is marked as unresolved
    ingredient_id: str | None = None
    suggested_id: str | None = None # suggests an ID but can not be marked as confirmed. Must be careful
    candidate_ids: tuple[str, ...] = ()
    warning: Mapping[str, Any] | None = None


@dataclass(frozen=True)
class PreparedProductAnalysisInput:
    """
    Product is validated and ready to proceed into analysis engine.

    `confirmed_ids` contains catalog members from rows marked confirmed.
    `rule_eligible_ids` is empty when the stored catalog version is stale or
    missing; callers must refresh those mappings before applying rules.
    Partial lists can still produce findings for their confirmed rows, while
    `uncertainty_preserved` remains true for the overall product result.
    """

    product_id: str
    list_status: str
    catalog_version: int | None #version numbers help to determine if the mapping for an ingredient may be out of date and shoul be updated
    active_catalog_version: int
    confirmed_ids: tuple[str, ...]
    unresolved_ingredients: tuple[UnresolvedIngredient, ...]
    uncertainty_preserved: bool # notes if any ingredients in the product remain uncertain
    requires_refresh: bool # used to ensure all ids are loaded before entering rule analysis engine
    incomplete_reasons: tuple[str, ...]

    @property
    def rule_eligible_ids(self) -> tuple[str, ...]:
        """Confirmed IDs safe to compare with rules for the active catalog."""

        return () if self.requires_refresh else self.confirmed_ids #will not provide and mark as "confirmed IDs" unless catalog version it used for verification is most recent version.


def load_alias_catalog(path: str | Path) -> dict[str, Any]:
    """Load the bundled "ingredient-aliases.json" catalog"""

    catalog_path = Path(path)
    try:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    except OSError as error:
        raise ProductInputError(f"Could not read alias catalog {catalog_path}: {error}") from error
    except json.JSONDecodeError as error:
        raise ProductInputError(f"Alias catalog {catalog_path} is not valid JSON: {error}") from error

    _catalog_members(catalog) # gets catalog version and mapped ingredient IDs
    return catalog


def prepare_analysis_input(
    product_record: Mapping[str, Any], alias_catalog: Mapping[str, Any]
) -> PreparedProductAnalysisInput:
    """
    Prepare a product record for analysis!
    
    Takes in full product record and most recent, updated catalog version to validate 
    everything and create a product object ready to be sent into analysis engine.

    This function does not maps raw text to a new ID. The Swift normalizer owns
    that job. A syntactically valid but unknown stored ID is kept unresolved.
    """

    #retrieve catalog ersion and ingredients to begin structuring analysis input
    catalog_version, catalog_ids = _catalog_members(alias_catalog)

    if not isinstance(product_record, Mapping):
        raise ProductInputError("Product record must be a JSON object.")

    product_id = product_record.get("productID")
    if not isinstance(product_id, str) or not product_id.strip():
        raise ProductInputError("Product record needs a non-empty productID.")

    list_status = product_record.get("listStatus")
    if not isinstance(list_status, str) or list_status not in _LIST_STATUSES:
        raise ProductInputError("listStatus must be complete, partial, or unavailable.")

    stored_version = product_record.get("catalogVersion")
    if stored_version is not None and (type(stored_version) is not int or stored_version < 0):
        raise ProductInputError("catalogVersion must be a non-negative integer or null.")

    rows = product_record.get("ingredients")
    if not isinstance(rows, list):
        raise ProductInputError("ingredients must be an array of normalized ingredient rows.")

    reasons: list[str] = []
    
    # helper function to create reasons list on why the ingredient is unresolved, will use simple and intuitive reason tags
    def add_reason(reason: str) -> None:
        if reason not in reasons:
            reasons.append(reason)

    requires_refresh = stored_version != catalog_version #checks if ingredient list is out of date and needs to be updated
    if stored_version is None:
        add_reason("catalog_version_missing")
    elif requires_refresh:
        add_reason("catalog_version_outdated")

    if list_status == "partial":
        add_reason("ingredient_list_partial")
    elif list_status == "unavailable":
        add_reason("ingredient_list_unavailable")
        if rows: # marked as unavailable ingredients but has available ingredients == mismatch
            add_reason("list_status_row_count_mismatch")
    elif list_status == "complete" and not rows: # marked as complete list but contains no ingredients == empty list
        add_reason("empty_complete_ingredient_list")

    #create seperate lists of confirmed ingredients and unresolved for analysis engine to easily decipher
    confirmed_ids: list[str] = []
    unresolved: list[UnresolvedIngredient] = [] 

    # find each ingredient in product and evaluate
    for index, row in enumerate(rows):
        parsed = _parse_ingredient_row(row, index)
        mapping = parsed["mapping"]
        ingredient_id = parsed["ingredient_id"]

        # confirmed ingredients
        if mapping == "confirmed" and ingredient_id in catalog_ids:
            confirmed_ids.append(ingredient_id)
            continue

        # unresolved ingredients
        if mapping == "confirmed": #confirmed but id is not in most recent catalog version
            row_reason = "confirmed_id_not_in_active_catalog"
            add_reason(row_reason)
        else:
            row_reason = "ingredient_mapping_needs_review"
            add_reason("unresolved_ingredient")

        unresolved.append(
            UnresolvedIngredient(
                original_text=parsed["original_text"],
                mapping=mapping,
                reason=row_reason,
                ingredient_id=ingredient_id,
                suggested_id=parsed["suggested_id"],
                candidate_ids=parsed["candidate_ids"],
                warning=parsed["warning"],
            )
        )

    #put it all together for a complete, verified, and structured product data entry, containing all necessary info future analysis engine will need
    return PreparedProductAnalysisInput(
        product_id=product_id,
        list_status=list_status,
        catalog_version=stored_version,
        active_catalog_version=catalog_version,
        confirmed_ids=tuple(confirmed_ids),
        unresolved_ingredients=tuple(unresolved), # confirmed and unresolved ingredients are separated but both included
        uncertainty_preserved=bool(reasons),
        requires_refresh=requires_refresh,
        incomplete_reasons=tuple(reasons),
    )


def _catalog_members(alias_catalog: Mapping[str, Any]) -> tuple[int, set[str]]:

    """
    Collects catalog version number and creates a set of all ingredient with correct canonical ID.
    Returns catalog version number and ingredients set.
    """

    #catalog must be type object (specifically JSON obj)
    if not isinstance(alias_catalog, Mapping): #Mapping is a JSON object
        raise ProductInputError("Alias catalog must be a JSON object.")

    # get catalog version we are using to be used as an identifier
    version = alias_catalog.get("version")

    #error handling, version but be non-negative int
    if type(version) is not int or version < 0:
        raise ProductInputError("Alias catalog version must be a non-negative integer.")

    #ingredients must be type list
    ingredients = alias_catalog.get("ingredients")
    if not isinstance(ingredients, list):
        raise ProductInputError("Alias catalog ingredients must be an array.")

    # create a set of all ingredients in the product so none are repeated
    ingredient_ids: set[str] = set()
    for index, ingredient in enumerate(ingredients):

        # verify ingredient is an object
        if not isinstance(ingredient, Mapping):
            raise ProductInputError(f"Alias catalog ingredient at index {index} must be an object.")

        # get corresponding canonical ID
        ingredient_id = ingredient.get("id")

        # verify canonical mapping was done with correct format
        if not _is_canonical_id(ingredient_id):
            raise ProductInputError(f"Alias catalog ingredient at index {index} has an invalid ID.")

        # verify no repeated ingredients in our set
        if ingredient_id in ingredient_ids:
            raise ProductInputError(f"Alias catalog repeats ingredient ID {ingredient_id!r}.")

        # add the ingredient to out ingredient IDs list (set)
        ingredient_ids.add(ingredient_id)

    return version, ingredient_ids


def _parse_ingredient_row(row: Any, index: int) -> dict[str, Any]:

    """
    Helper function to parse adn verify one ingredient row. 
    Will accept either the newer mapping format or older status but not a row that contains both. Validates all feilds meets what its marked mapping state entails. 
    Returns: the ingredients' structured and verified attributes.  
    """

    if not isinstance(row, Mapping):
        raise ProductInputError(f"Ingredient row at index {index} must be an object.")

    original_text = row.get("originalText")
    if not isinstance(original_text, str):
        raise ProductInputError(f"Ingredient row at index {index} needs originalText.")

    # reject when both mapping and older status for a single ingredient exists because they could disagree (mapping is our newer method, status is the old but must check for both to be safe)
    has_mapping = "mapping" in row
    has_legacy_status = "status" in row
    if has_mapping and has_legacy_status:
        raise ProductInputError(f"Ingredient row at index {index} cannot contain both mapping and status.")

    if has_mapping:
        mapping = row.get("mapping")
        if not isinstance(mapping, str) or mapping not in _MAPPINGS:
            raise ProductInputError(f"Ingredient row at index {index} has an invalid mapping state.")
        fields = row
    elif has_legacy_status:
        mapping, fields = _parse_legacy_status(row["status"], index) #send to seperate helper made for legacy status
    else:
        raise ProductInputError(f"Ingredient row at index {index} needs mapping or legacy status.")


    ingredient_id = fields.get("ingredientID")
    suggested_id = fields.get("suggestedID")
    candidate_ids = fields.get("candidateIDs", []) # return empty list if no candidates exist!

    # verify all names are in canonicalid format ensuring mappings
    for field_name, value in (("ingredientID", ingredient_id), ("suggestedID", suggested_id)):
        if value is not None and not _is_canonical_id(value):
            raise ProductInputError(f"Ingredient row at index {index} has an invalid {field_name}.")

    if not isinstance(candidate_ids, list) or any(not _is_canonical_id(value) for value in candidate_ids):
        raise ProductInputError(f"Ingredient row at index {index} has invalid candidateIDs.")
    if len(candidate_ids) != len(set(candidate_ids)):
        raise ProductInputError(f"Ingredient row at index {index} repeats a candidate ID.")

    # validate mappings with expected values/ shape for other attribtues (ie. if it is a confirmed mapping is should not have suggested or candidate IDs)
    if mapping == "confirmed":
        valid_shape = ingredient_id is not None and suggested_id is None and not candidate_ids
    elif mapping == "uncertain":
        valid_shape = ingredient_id is None and suggested_id is not None and not candidate_ids
    elif mapping == "ambiguous":
        valid_shape = ingredient_id is None and suggested_id is None and len(candidate_ids) >= 2
    # else completely unmatched
    else:
        valid_shape = ingredient_id is None and suggested_id is None and not candidate_ids
    if not valid_shape:
        raise ProductInputError(f"Ingredient row at index {index} has fields inconsistent with mapping={mapping!r}.")

    warning = fields.get("warning")
    if warning is not None and not isinstance(warning, Mapping):
        raise ProductInputError(f"Ingredient row at index {index} warning must be an object or null.")

    #put all parsed and validated attributes together for that ingredient
    return {
        "original_text": original_text,
        "mapping": mapping,
        "ingredient_id": ingredient_id,
        "suggested_id": suggested_id,
        "candidate_ids": tuple(candidate_ids),
        "warning": warning,
    }


def _parse_legacy_status(status: Any, index: int) -> tuple[str, Mapping[str, Any]]:
    if not isinstance(status, Mapping) or len(status) != 1:
        raise ProductInputError(f"Legacy status at ingredient row {index} must be a one-case object.")

    legacy_state, payload = next(iter(status.items()))
    legacy_mapping = {
        "matched": "confirmed", # where legacy and newer status differ
        "uncertain": "uncertain",
        "ambiguous": "ambiguous",
        "unmatched": "unmatched",
    }.get(legacy_state)
    if legacy_mapping is None:
        raise ProductInputError(f"Legacy status at ingredient row {index} has an unknown state.")
    if not isinstance(payload, Mapping):
        raise ProductInputError(f"Legacy status payload at ingredient row {index} must be an object.")

    return legacy_mapping, payload # return corrected mapping and corresponding feild back to parser


def _is_canonical_id(value: Any) -> bool: 
    # ensures correct canonical ID format!
    return isinstance(value, str) and _CANONICAL_ID.fullmatch(value) is not None
