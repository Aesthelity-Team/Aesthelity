"""Evaluate a skincare routine against the reviewed AN-02 rule contract.

This module matches only confirmed ingredient IDs from the active catalog. A
missing finding means that no current rule matched; it is not a safety claim.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from .product_input import (
    ProductInputError,
    _catalog_members,
    _is_canonical_id,
    _parse_ingredient_row,
)


_LIMITATIONS = [
    "Team-approved v1 rules. This is not clinically validated or a safety guarantee. "
    "Severity, when present, is display priority and not a clinical grade."
]
_MICROSPHERE_LIMITATION = (
    "The 2002 microsphere study kept 87% of tretinoin after 24 hours. No conflict "
    "here means this is not the 1998 mixture, not that the amount was unchanged."
)
_FORMULATION_VEHICLES = {
    "conventional-gel",
    "lotion",
    "optimized-aqueous-gel",
    "microsphere-gel",
    "unknown",
}
_ACTIVE_IRRITANTS = {"retinol", "benzoyl-peroxide", "tretinoin"}


class AnalysisInputError(ValueError):
    """Invalid routine input, with a stable code for callers and UI handling."""

    def __init__(self, code: str, message: str | None = None):
        self.code = code
        super().__init__(message or code)


def evaluate_routine(routine: dict[str, Any], catalog: dict[str, Any]) -> dict[str, Any]:
    """Validate and evaluate one AM or PM routine.

    `routine` contains normalized product records, a recorded-allergy state,
    and optional coapplication context. `catalog` is the active ingredient
    alias catalog. The returned object follows the AN-02 result contract.
    """

    catalog_version, catalog_ids = _catalog_members(catalog)
    catalog_classes = _catalog_classes(catalog)
    period, allergies, coapplication, products = _validate_routine(routine, catalog_ids)

    findings: list[dict[str, Any]] = []
    completeness = "complete"
    allergy_ids = set(allergies["ingredientIDs"]) if allergies["status"] == "known" else set()
    routine_has_benzoyl_peroxide = any(
        row.get("ingredient_id") == "benzoyl-peroxide" or row.get("eligible_id") == "benzoyl-peroxide"
        for product in products
        for row in product["ingredients"]
    )

    for product in products:
        product_findings, product_complete = _coverage_for_product(
            product,
            catalog_version,
            allergy_ids=allergy_ids,
            routine_has_benzoyl_peroxide=routine_has_benzoyl_peroxide,
        )
        findings.extend(product_findings)
        if not product_complete:
            completeness = "incomplete"

    if allergies["status"] == "unknown":
        findings.append(
            _coverage_finding(
                "coverage.allergy-input-unknown",
                "The routine does not say whether allergies were recorded, so no allergen result is produced.",
                "status unknown is not an empty allergy list.",
                [product["productID"] for product in products],
            )
        )
        completeness = "incomplete"
    else:
        for ingredient_id in allergies["ingredientIDs"]:
            if ingredient_id not in catalog_ids:
                findings.append(
                    _coverage_finding(
                        "coverage.allergy-id-absent",
                        f"Recorded allergy ID {ingredient_id} is not in the active catalog, so it cannot be matched to a product row.",
                        "A valid recorded slug that is absent from the active catalog is not treated as a match.",
                        [],
                        ingredient_ids=[ingredient_id],
                        reason_code="absent-catalog-id",
                    )
                )
                completeness = "incomplete"

    rule_products = [product for product in products if product["rule_eligible"]]
    findings.extend(_caution_findings(rule_products, catalog_classes, catalog))
    findings.extend(_allergen_findings(rule_products, allergies, catalog))

    tretinoin_findings, tretinoin_context_incomplete, extra_limitations = _tretinoin_bpo_findings(
        rule_products, coapplication
    )
    findings.extend(tretinoin_findings)
    if tretinoin_context_incomplete:
        completeness = "incomplete"

    findings.sort(key=lambda finding: _finding_sort_key(finding, products))
    outcome = "findings" if findings else "noFindings"

    limitations = list(_LIMITATIONS)
    for limitation in extra_limitations:
        if limitation not in limitations:
            limitations.append(limitation)

    result = {
        "period": period,
        "activeCatalogVersion": catalog_version,
        "outcome": outcome,
        "completeness": completeness,
        "productIDs": [product["productID"] for product in products],
        "findings": findings,
        "limitations": limitations,
    }
    if outcome == "noFindings":
        result["displayLabel"] = "No recorded conflicts"
    return result


def _validate_routine(routine: Any, catalog_ids: set[str]) -> tuple[str, dict[str, Any], str | None, list[dict[str, Any]]]:
    if not isinstance(routine, Mapping) or not isinstance(routine.get("period"), str) or routine.get("period") not in {"am", "pm"}:
        raise AnalysisInputError("missing-period", "period must be 'am' or 'pm'.")

    allergies = routine.get("recordedAllergies")
    if not isinstance(allergies, Mapping) or not isinstance(allergies.get("status"), str) or allergies.get("status") not in {"known", "unknown"}:
        raise AnalysisInputError(
            "missing-recorded-allergies",
            "recordedAllergies must have status 'known' or 'unknown'.",
        )
    if allergies["status"] == "unknown":
        if "ingredientIDs" in allergies:
            raise AnalysisInputError(
                "allergy-unknown-has-ids",
                "Unknown recorded allergies cannot include ingredientIDs.",
            )
        normalized_allergies = {"status": "unknown", "ingredientIDs": []}
    else:
        allergy_ids = allergies.get("ingredientIDs")
        if not isinstance(allergy_ids, list):
            raise AnalysisInputError(
                "allergy-known-missing-ids",
                "Known recorded allergies need an ingredientIDs array.",
            )
        if any(not _is_canonical_id(ingredient_id) for ingredient_id in allergy_ids):
            raise AnalysisInputError("invalid-id", "Recorded allergy IDs must be canonical slugs.")
        if len(set(allergy_ids)) != len(allergy_ids):
            raise AnalysisInputError("row-shape", "Recorded allergy IDs must be unique.")
        normalized_allergies = {"status": "known", "ingredientIDs": list(allergy_ids)}

    raw_products = routine.get("products")
    if not isinstance(raw_products, list) or not raw_products:
        raise AnalysisInputError("empty-products", "products must be a non-empty array.")

    # Validate product identifiers and list states before nested row data. This
    # preserves the documented first-error order.
    product_ids: list[str] = []
    for product in raw_products:
        if not isinstance(product, Mapping):
            raise AnalysisInputError("row-shape", "Each product must be an object.")
        product_id = product.get("productID")
        if not isinstance(product_id, str) or not product_id.strip():
            raise AnalysisInputError("row-shape", "Each product needs a non-empty productID.")
        if product_id in product_ids:
            raise AnalysisInputError("duplicate-product-id", f"Duplicate productID: {product_id}.")
        product_ids.append(product_id)
        if not isinstance(product.get("listStatus"), str) or product.get("listStatus") not in {"complete", "partial", "unavailable"}:
            raise AnalysisInputError(
                "list-status",
                "listStatus must be complete, partial, or unavailable.",
            )

    coapplication = routine.get("coapplication")
    if coapplication is not None and (
        not isinstance(coapplication, str) or coapplication not in {"mixed", "not-mixed", "unknown"}
    ):
        raise AnalysisInputError(
            "invalid-coapplication",
            "coapplication must be mixed, not-mixed, or unknown.",
        )

    products: list[dict[str, Any]] = []
    for raw in raw_products:
        rows = raw.get("ingredients")
        if not isinstance(rows, list):
            raise AnalysisInputError("row-shape", "ingredients must be an array.")
        catalog_version = raw.get("catalogVersion")
        if catalog_version is not None and (type(catalog_version) is not int or catalog_version < 0):
            raise AnalysisInputError("row-shape", "catalogVersion must be a non-negative integer or null.")

        parsed_rows: list[dict[str, Any]] = []
        for index, row in enumerate(rows):
            try:
                parsed = _parse_ingredient_row(row, index)
            except ProductInputError as error:
                message = str(error)
                if any(token in message for token in ("invalid ingredientID", "invalid suggestedID", "invalid candidateIDs")):
                    code = "invalid-id"
                else:
                    code = "row-shape"
                raise AnalysisInputError(code, message) from error

            formulation = _formulation_for_row(row)
            parsed["formulation"] = formulation
            parsed["row_index"] = index
            parsed["eligible_id"] = (
                parsed["ingredient_id"]
                if parsed["mapping"] == "confirmed" and parsed["ingredient_id"] in catalog_ids
                else None
            )
            parsed_rows.append(parsed)

        # Formulation validation follows the ingredient row and ID validation.
        for parsed in parsed_rows:
            if parsed["formulation"] is not None:
                _validate_formulation(parsed["formulation"])

        status = raw["listStatus"]
        contradictory = (status == "unavailable" and bool(rows)) or (
            status in {"complete", "partial"} and not rows
        )
        products.append(
            {
                "productID": raw["productID"],
                "listStatus": status,
                "catalogVersion": catalog_version,
                "ingredients": parsed_rows,
                "contradictory": contradictory,
                "rule_eligible": not contradictory,
            }
        )

    return routine["period"], normalized_allergies, coapplication, products
def _catalog_classes(catalog: Mapping[str, Any]) -> dict[str, set[str]]:
    classes: dict[str, set[str]] = {}
    ingredients = catalog.get("ingredients", [])
    if not isinstance(ingredients, list):
        return classes
    for item in ingredients:
        if not isinstance(item, Mapping):
            continue
        ingredient_id = item.get("id")
        raw_classes = item.get("classes", [])
        if isinstance(ingredient_id, str) and isinstance(raw_classes, list):
            classes[ingredient_id] = {value for value in raw_classes if isinstance(value, str)}
    return classes


def _coverage_for_product(
    product: dict[str, Any],
    catalog_version: int,
    *,
    allergy_ids: set[str] | None = None,
    routine_has_benzoyl_peroxide: bool = False,
) -> tuple[list[dict[str, Any]], bool]:
    product_id = product["productID"]
    status = product["listStatus"]
    rows = product["ingredients"]
    stored_version = product["catalogVersion"]
    findings: list[dict[str, Any]] = []
    complete = True
    allergy_ids = allergy_ids or set()

    if product["contradictory"]:
        known_names = [row["ingredient_id"] for row in rows if row["ingredient_id"]]
        product_label = known_names[0].replace("-", " ").lower() if known_names else product_id
        findings.append(
            _coverage_finding(
                "coverage.contradictory-list-status",
                f"The {product_label} product says the list is unavailable and also stores a row. Those IDs are not matched."
                if status == "unavailable" and rows
                else f"{product_id} has a list status that contradicts its ingredient rows. Those IDs are not matched.",
                "A contradictory list is excluded from caution, conflict, and allergen matches.",
                [product_id],
            )
        )
        product["rule_eligible"] = False
        return findings, False

    if stored_version is None:
        findings.append(
            _coverage_finding(
                "coverage.missing-catalog-version",
                f"{product_id} has no stored catalog version, so its ingredient IDs were not used as matches.",
                "The product catalogVersion is null or missing.",
                [product_id],
            )
        )
        product["rule_eligible"] = False
        complete = False
    elif stored_version != catalog_version:
        findings.append(
            _coverage_finding(
                "coverage.stale-catalog",
                f"{product_id} was stored with catalog version {stored_version}. The active catalog is version {catalog_version}, so its IDs were not used as matches.",
                "catalogVersion does not equal the catalog version passed to the engine.",
                [product_id],
            )
        )
        product["rule_eligible"] = False
        complete = False

    if status == "partial":
        findings.append(
            _coverage_finding(
                "coverage.partial-list",
                f"{product_id} is marked partial. Rows that are absent were not checked.",
                "listStatus is partial and the stored rows are only the known portion.",
                [product_id],
            )
        )
        complete = False
    elif status == "unavailable":
        findings.append(
            _coverage_finding(
                "coverage.unavailable-list",
                f"{product_id} has no ingredient rows, so no ingredient could be checked.",
                "listStatus is unavailable and the ingredient array is empty.",
                [product_id],
            )
        )
        product["rule_eligible"] = False
        complete = False

    if product["rule_eligible"]:
        for row in rows:
            if row["mapping"] == "confirmed" and row["eligible_id"] is None:
                reason_code = "absent-catalog-id"
            elif row["mapping"] != "confirmed":
                reason_code = row["mapping"]
            else:
                continue
            findings.append(
                _unresolved_row_finding(
                    product,
                    row,
                    reason_code,
                    allergy_ids=allergy_ids,
                    routine_has_benzoyl_peroxide=routine_has_benzoyl_peroxide,
                )
            )
            complete = False

    if stored_version is None or stored_version != catalog_version:
        complete = False
    if status != "complete":
        complete = False
    if any(row["mapping"] != "confirmed" or row["eligible_id"] is None for row in rows):
        complete = False

    return findings, complete


def _unresolved_row_finding(
    product: Mapping[str, Any],
    row: Mapping[str, Any],
    reason_code: str,
    *,
    allergy_ids: set[str] | None = None,
    routine_has_benzoyl_peroxide: bool = False,
) -> dict[str, Any]:
    text = row["original_text"]
    ingredient_id = row["ingredient_id"]
    suggested_id = row.get("suggested_id")
    allergy_ids = allergy_ids or set()
    if reason_code == "ambiguous":
        explanation = f"{text} is not a rule-eligible identity."
        reason = "Candidate IDs are not confirmed matches."
    elif reason_code == "uncertain":
        if isinstance(suggested_id, str) and suggested_id in allergy_ids:
            explanation = (
                f"The recorded allergy names {suggested_id}, but this row only suggests it."
            )
        else:
            explanation = f"{text} is not a rule-eligible identity."
        reason = "suggestedID is not a confirmed match."
    elif reason_code == "unmatched":
        explanation = f"{text} is not a rule-eligible identity."
        reason = "The row has no confirmed ID."
    elif (
        reason_code == "absent-catalog-id"
        and ingredient_id == "tretinoin"
        and routine_has_benzoyl_peroxide
    ):
        explanation = (
            "tretinoin is not in the bundled version 3 catalog, so the benzoyl peroxide conflict does not fire."
        )
        reason = "A slug can be stored without being a catalog member."
    else:
        explanation = f"{text} is not a rule-eligible identity."
        reason = f"{ingredient_id} is not in the bundled catalog."
    finding = _coverage_finding(
        "coverage.unresolved-row",
        explanation,
        reason,
        [product["productID"]],
        reason_code=reason_code,
    )
    finding["originalText"] = text
    finding["rowIndex"] = row["row_index"]
    return finding


def _caution_findings(
    products: list[dict[str, Any]],
    catalog_classes: Mapping[str, set[str]],
    catalog: Mapping[str, Any],
) -> list[dict[str, Any]]:
    eligible = [
        (product, row)
        for product in products
        for row in product["ingredients"]
        if row["eligible_id"] is not None
    ]
    active_rows = [(product, row) for product, row in eligible if row["eligible_id"] in _ACTIVE_IRRITANTS]
    exfoliant_rows = [
        (product, row)
        for product, row in eligible
        if "exfoliant" in catalog_classes.get(row["eligible_id"], set())
    ]
    pairs = [
        (active_product, active_row, exfoliant_product, exfoliant_row)
        for active_product, active_row in active_rows
        for exfoliant_product, exfoliant_row in exfoliant_rows
        if active_row["eligible_id"] != exfoliant_row["eligible_id"]
    ]
    if not pairs:
        return []

    active_ids = _ordered_unique(pair[1]["eligible_id"] for pair in pairs)
    exfoliant_ids = _ordered_unique(pair[3]["eligible_id"] for pair in pairs)
    ingredient_ids = _routine_order_ids(products, set(active_ids + exfoliant_ids))
    involved_product_ids = _routine_order_product_ids(
        products,
        {
            product["productID"]
            for active_product, _, exfoliant_product, _ in pairs
            for product in (active_product, exfoliant_product)
        },
    )

    default_reason = (
        "The rule matches retinol, benzoyl peroxide, or tretinoin with class exfoliant. "
        "Repeated retinol rows are one identity. Order is not a match condition."
    )
    if len(active_ids) == 1 and len(exfoliant_ids) == 1:
        active_name = _display_name(active_ids[0], catalog).lower()
        exfoliant_name = _display_name(exfoliant_ids[0], catalog).lower()
        involved_partial = any(
            product["listStatus"] == "partial"
            for product, _ in eligible
            if product["productID"] in involved_product_ids
        )
        if involved_partial:
            explanation = (
                f"Confirmed {active_name} is still rule-eligible on a partial list. "
                f"Confirmed {exfoliant_name} has class exfoliant. The American Academy of Dermatology caution still applies to the rows that are present."
            )
            reason = (
                "A partial list does not erase a confirmed row, and it does not make the missing rows known."
            )
        else:
            explanation = (
                "The American Academy of Dermatology says products containing retinol or benzoyl peroxide may make skin more sensitive, "
                "and exfoliating while using them may worsen dryness or cause breakouts. "
                f"Confirmed {active_name} and confirmed {exfoliant_name}, class exfoliant, are both in this routine."
            )
            reason = default_reason
    else:
        names = ", ".join(_display_name(value, catalog).lower() for value in ingredient_ids)
        explanation = (
            "The American Academy of Dermatology says products containing retinol or benzoyl peroxide may make skin more sensitive, "
            "and exfoliating while using them may worsen dryness or cause breakouts. "
            f"Confirmed ingredients {names} include an exfoliant and a named active in this routine."
        )
        reason = default_reason

    return [
        {
            "ruleStatus": "approved",
            "explanation": explanation,
            "reason": reason,
            "limitations": list(_LIMITATIONS),
            "ruleID": "irritation.retinol-benzoyl-peroxide-with-exfoliant",
            "outcome": "caution",
            "categoryID": "ingredient-combination",
            "severity": "moderate",
            "productIDs": involved_product_ids,
            "ingredientIDs": ingredient_ids,
            "matchedClassIDs": ["exfoliant"],
        }
    ]


def _allergen_findings(
    products: list[dict[str, Any]], allergies: Mapping[str, Any], catalog: Mapping[str, Any]
) -> list[dict[str, Any]]:
    if allergies["status"] != "known" or not allergies["ingredientIDs"]:
        return []
    allergy_ids = set(allergies["ingredientIDs"])
    matches = [
        (product, row)
        for product in products
        for row in product["ingredients"]
        if row["eligible_id"] in allergy_ids
    ]
    if not matches:
        return []

    ingredient_ids = _ordered_unique(row["eligible_id"] for _, row in matches)
    product_ids = _routine_order_product_ids(products, {product["productID"] for product, _ in matches})
    if ingredient_ids == ["limonene"] and len(product_ids) == 1:
        product_id = product_ids[0]
        explanation = (
            f"The recorded allergy list names limonene, and {product_id} has a confirmed limonene row. "
            "EU Annex III entry 88 requires limonene to be named on the label above a concentration threshold so a sensitised person can see it. A name on a label is not itself an allergy."
        )
    else:
        named_ids = ", ".join(ingredient_ids)
        explanation = (
            f"The recorded allergy list names {named_ids}, and the listed product rows contain those exact confirmed ingredient IDs."
        )
    return [
        {
            "ruleStatus": "approved",
            "explanation": explanation,
            "reason": "The match is exact confirmed ID equality. Class fragrance-allergen is not the match key.",
            "limitations": list(_LIMITATIONS),
            "ruleID": "allergy.recorded-ingredient",
            "outcome": "allergen",
            "categoryID": "recorded-allergy",
            "severity": "high",
            "productIDs": product_ids,
            "ingredientIDs": ingredient_ids,
        }
    ]


def _tretinoin_bpo_findings(
    products: list[dict[str, Any]], coapplication: str | None
) -> tuple[list[dict[str, Any]], bool, list[str]]:
    bpo_rows = [
        (product, row)
        for product in products
        for row in product["ingredients"]
        if row["eligible_id"] == "benzoyl-peroxide"
    ]
    tretinoin_rows = [
        (product, row)
        for product in products
        for row in product["ingredients"]
        if row["eligible_id"] == "tretinoin"
    ]
    if not bpo_rows or not tretinoin_rows:
        return [], False, []

    ingredient_ids = _routine_order_ids(products, {"benzoyl-peroxide", "tretinoin"})
    all_pairs = [
        (bpo_product, bpo_row, tret_product, tret_row)
        for bpo_product, bpo_row in bpo_rows
        for tret_product, tret_row in tretinoin_rows
    ]

    exact_conflict_pairs = [
        pair for pair in all_pairs
        if _is_formulation(pair[1]["formulation"], "lotion", 10)
        and _is_formulation(pair[3]["formulation"], "conventional-gel", 0.025)
    ]
    if exact_conflict_pairs and coapplication == "mixed":
        conflict_product_ids = _routine_order_product_ids(
            products,
            {
                product["productID"]
                for bpo_product, _, tret_product, _ in exact_conflict_pairs
                for product in (bpo_product, tret_product)
            },
        )
        explanation = (
            "Martin and colleagues mixed equal volumes of tretinoin 0.025% gel and benzoyl peroxide 10% lotion. "
            "With benzoyl peroxide and light, more than 50% of the tretinoin was gone in about two hours and 95% in 24 hours. "
            "This routine states that conventional gel, that lotion, and mixed coapplication."
        )
        return [
            {
                "ruleStatus": "approved",
                "explanation": explanation,
                "reason": "Conflict means that studied mixture changed the tretinoin. It does not mean every tretinoin formula conflicts with benzoyl peroxide.",
                "limitations": list(_LIMITATIONS),
                "ruleID": "interaction.benzoyl-peroxide-with-tretinoin",
                "outcome": "conflict",
                "categoryID": "ingredient-interaction",
                "severity": "high",
                "productIDs": conflict_product_ids,
                "ingredientIDs": ingredient_ids,
            }
        ], False, []

    microsphere_pair = any(
        _is_formulation(tret_row["formulation"], "microsphere-gel", 0.1)
        for _, _, _, tret_row in all_pairs
    )
    optimized_pair = any(
        _is_formulation(tret_row["formulation"], "optimized-aqueous-gel", 0.05)
        for _, _, _, tret_row in all_pairs
    )
    if (microsphere_pair or optimized_pair) and coapplication == "mixed":
        extras = [_MICROSPHERE_LIMITATION] if microsphere_pair else []
        return [], False, extras

    product_ids = _routine_order_product_ids(
        products,
        {product["productID"] for product, _ in bpo_rows + tretinoin_rows},
    )

    formulations_known = all(
        _known_formulation(row["formulation"])
        for _, bpo_row, _, tret_row in all_pairs
        for row in (bpo_row, tret_row)
    )
    if not formulations_known:
        reason_code = "formulation-unknown"
        if all(
            row["formulation"] is None
            for _, bpo_row, _, tret_row in all_pairs
            for row in (bpo_row, tret_row)
        ) and coapplication is None:
            explanation = (
                "Benzoyl peroxide and tretinoin are confirmed, but neither row states vehicle and concentration, "
                "and coapplication is omitted. The 1998 loss result is not applied."
            )
        else:
            explanation = (
                "Benzoyl peroxide and tretinoin are confirmed, but their formulation context is incomplete. "
                "The 1998 loss result is not applied."
            )
    elif coapplication in {None, "unknown"}:
        reason_code = "coapplication-unknown"
        explanation = (
            "The studied tretinoin gel and benzoyl peroxide lotion are confirmed, but the routine does not say whether they were mixed. "
            "The 1998 loss result is not applied."
        )
    else:
        reason_code = "coapplication-not-studied"
        explanation = (
            "The products are not marked as mixed, so the studied mixture condition is not established. "
            "The 1998 loss result is not applied."
        )

    finding = _coverage_finding(
        "coverage.tretinoin-bpo-context-unknown",
        explanation,
        "Unknown formulation context is a review item, not a conflict."
        if reason_code == "formulation-unknown"
        else "Unknown coapplication context is a review item, not a conflict.",
        product_ids,
        ingredient_ids=ingredient_ids,
        reason_code=reason_code,
    )
    return [finding], True, []


def _formulation_for_row(row: Any) -> Any:
    if not isinstance(row, Mapping):
        return None
    if "formulation" in row:
        return row["formulation"]
    status = row.get("status")
    if isinstance(status, Mapping) and len(status) == 1:
        payload = next(iter(status.values()))
        if isinstance(payload, Mapping):
            return payload.get("formulation")
    return None


def _validate_formulation(formulation: Any) -> None:
    if not isinstance(formulation, Mapping) or not {"vehicle", "concentrationPercent"}.issubset(formulation):
        raise AnalysisInputError("invalid-formulation", "formulation needs vehicle and concentrationPercent fields.")
    vehicle = formulation.get("vehicle")
    concentration = formulation.get("concentrationPercent")
    if not isinstance(vehicle, str) or vehicle not in _FORMULATION_VEHICLES:
        raise AnalysisInputError("invalid-formulation", "formulation.vehicle is not supported.")
    if concentration is not None and (
        isinstance(concentration, bool)
        or not isinstance(concentration, (int, float))
        or concentration < 0
    ):
        raise AnalysisInputError(
            "invalid-formulation",
            "formulation.concentrationPercent must be a non-negative number or null.",
        )


def _known_formulation(formulation: Any) -> bool:
    return (
        isinstance(formulation, Mapping)
        and formulation.get("vehicle") in _FORMULATION_VEHICLES - {"unknown"}
        and isinstance(formulation.get("concentrationPercent"), (int, float))
        and not isinstance(formulation.get("concentrationPercent"), bool)
    )


def _is_formulation(formulation: Any, vehicle: str, concentration: float) -> bool:
    return (
        isinstance(formulation, Mapping)
        and formulation.get("vehicle") == vehicle
        and formulation.get("concentrationPercent") == concentration
    )


def _coverage_finding(
    rule_id: str,
    explanation: str,
    reason: str,
    product_ids: list[str],
    *,
    ingredient_ids: list[str] | None = None,
    reason_code: str | None = None,
) -> dict[str, Any]:
    finding = {
        "ruleStatus": "approved",
        "explanation": explanation,
        "reason": reason,
        "limitations": list(_LIMITATIONS),
        "ruleID": rule_id,
        "outcome": "unknown",
        "categoryID": "coverage-gap",
        "productIDs": list(product_ids),
        "ingredientIDs": list(ingredient_ids or []),
    }
    if reason_code is not None:
        finding["reasonCode"] = reason_code
    return finding


def _display_name(ingredient_id: str, catalog: Mapping[str, Any]) -> str:
    for item in catalog.get("ingredients", []):
        if isinstance(item, Mapping) and item.get("id") == ingredient_id:
            name = item.get("name")
            if isinstance(name, str) and name:
                return name
    return ingredient_id.replace("-", " ")


def _ordered_unique(values: Any) -> list[str]:
    result: list[str] = []
    for value in values:
        if value not in result:
            result.append(value)
    return result


def _routine_order_ids(products: list[dict[str, Any]], ids: set[str]) -> list[str]:
    return _ordered_unique(
        row["eligible_id"]
        for product in products
        for row in product["ingredients"]
        if row["eligible_id"] in ids
    )


def _routine_order_product_ids(products: list[dict[str, Any]], ids: set[str]) -> list[str]:
    return [product["productID"] for product in products if product["productID"] in ids]


def _finding_sort_key(finding: Mapping[str, Any], products: list[dict[str, Any]]) -> tuple[Any, ...]:
    positions = {product["productID"]: index for index, product in enumerate(products)}
    earliest = min((positions[value] for value in finding["productIDs"] if value in positions), default=-1)
    rank = {"conflict": 0, "caution": 1, "allergen": 2, "unknown": 3}.get(finding["outcome"], 4)
    is_row = 1 if "rowIndex" in finding else 0
    row_index = finding.get("rowIndex", -1)
    return earliest, rank, is_row, row_index, finding["ruleID"]
