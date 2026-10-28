"""Runnable, self-contained demo for the AN-03 routine analysis engine.

Run from the project root with ``python3 -m analysis_engine.demo``.
Choose ``--case caution``, ``--case unknown``, ``--case conflict``, or
``--case no-findings`` to show a particular result shape.
"""

from __future__ import annotations

import argparse
import json
from typing import Any

from .evaluate import evaluate_routine


CATALOG: dict[str, Any] = {
    "version": 2,
    "ingredients": [
        {"id": "retinol", "name": "Retinol", "classes": ["retinoid"]},
        {"id": "benzoyl-peroxide", "name": "Benzoyl Peroxide", "classes": ["acne-treatment"]},
        {"id": "tretinoin", "name": "Tretinoin", "classes": ["retinoid"]},
        {"id": "glycolic-acid", "name": "Glycolic Acid", "classes": ["exfoliant"]},
        {"id": "water", "name": "Water", "classes": []},
        {"id": "limonene", "name": "Limonene", "classes": ["fragrance-allergen"]},
    ],
}


def _row(name: str, ingredient_id: str, **extra: Any) -> dict[str, Any]:
    return {
        "originalText": name,
        "mapping": "confirmed",
        "ingredientID": ingredient_id,
        **extra,
    }


def demo_input(case: str) -> dict[str, Any]:
    base: dict[str, Any] = {
        "period": "pm",
        "recordedAllergies": {"status": "known", "ingredientIDs": []},
        "products": [],
    }
    if case == "caution":
        base["products"] = [
            {"productID": "retinol-product", "listStatus": "complete", "catalogVersion": 2,
             "ingredients": [_row("Retinol", "retinol"), _row("Water", "water")]},
            {"productID": "glycolic-product", "listStatus": "complete", "catalogVersion": 2,
             "ingredients": [_row("Glycolic Acid", "glycolic-acid")]},
        ]
    elif case == "unknown":
        base["products"] = [
            {"productID": "unmapped-product", "listStatus": "partial", "catalogVersion": 2,
             "ingredients": [{"originalText": "Unrecognized botanical", "mapping": "unmatched"}]},
        ]
    elif case == "conflict":
        base["coapplication"] = "mixed"
        base["products"] = [
            {"productID": "tretinoin-product", "listStatus": "complete", "catalogVersion": 2,
             "ingredients": [_row("Tretinoin", "tretinoin", formulation={
                 "vehicle": "conventional-gel", "concentrationPercent": 0.025})]},
            {"productID": "benzoyl-peroxide-product", "listStatus": "complete", "catalogVersion": 2,
             "ingredients": [_row("Benzoyl Peroxide", "benzoyl-peroxide", formulation={
                 "vehicle": "lotion", "concentrationPercent": 10})]},
        ]
    elif case == "no-findings":
        base["products"] = [
            {"productID": "water-product", "listStatus": "complete", "catalogVersion": 2,
             "ingredients": [_row("Water", "water")]},
        ]
    else:
        raise ValueError(f"Unsupported demo case: {case}")
    return base


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--case",
        choices=("caution", "unknown", "conflict", "no-findings"),
        default="caution",
        help="which representative analysis result to print (default: caution)",
    )
    args = parser.parse_args()
    print(json.dumps(evaluate_routine(demo_input(args.case), CATALOG), indent=2))


if __name__ == "__main__":
    main()
