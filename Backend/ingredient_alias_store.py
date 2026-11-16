"""Load the approved shared ingredient alias catalog from Firestore."""

from __future__ import annotations

import copy
import re
from collections.abc import Mapping
from typing import Any

from analysis_engine.product_input import ProductInputError, _catalog_members


COLLECTION = "ingredientAliasCatalogs"
DOCUMENT_ID = "active"
_ID = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")


class IngredientAliasCatalogError(RuntimeError):
    """The approved alias catalog is invalid or cannot be read safely."""


def load_approved_alias_catalog(
    db: Any,
    bundled_catalog: Mapping[str, Any],
) -> tuple[dict[str, Any], str]:
    """Read the active approved catalog on each call, falling back to the bundle.

    The fallback preserves the deterministic catalog shipped with the app when
    Firestore has not been seeded yet or is temporarily unavailable. A valid
    Firestore update is visible on the next call.
    """
    try:
        snapshot = db.collection(COLLECTION).document(DOCUMENT_ID).get()
        if not snapshot.exists:
            return copy.deepcopy(dict(bundled_catalog)), "bundled-fallback"
        document = snapshot.to_dict() or {}
        catalog = {
            "version": document.get("version"),
            "ingredients": document.get("ingredients"),
            "ambiguousTerms": document.get("ambiguousTerms", []),
        }
        if document.get("reviewStatus") != "approved":
            raise IngredientAliasCatalogError("active_alias_catalog_unapproved")
        _validate_catalog(catalog)
        return catalog, "firestore"
    except IngredientAliasCatalogError:
        return copy.deepcopy(dict(bundled_catalog)), "bundled-fallback"
    except Exception:
        return copy.deepcopy(dict(bundled_catalog)), "bundled-fallback"


def _validate_catalog(catalog: Mapping[str, Any]) -> None:
    try:
        _catalog_members(catalog)
        ingredients = catalog["ingredients"]
        owner_by_name: dict[str, str] = {}
        known_ids = {item["id"] for item in ingredients}
        for item in ingredients:
            if not isinstance(item, Mapping):
                raise ValueError("ingredient must be an object")
            if not isinstance(item.get("name"), str) or not item["name"].strip():
                raise ValueError("ingredient name must be nonempty")
            aliases = item.get("aliases", [])
            classes = item.get("classes", [])
            if not isinstance(aliases, list) or not isinstance(classes, list):
                raise ValueError("aliases and classes must be arrays")
            if any(not isinstance(value, str) or not value.strip() for value in aliases):
                raise ValueError("aliases must be nonempty strings")
            if any(not isinstance(value, str) or not _ID.fullmatch(value) for value in classes):
                raise ValueError("classes must be canonical slugs")
            for name in [item["name"], *aliases]:
                key = _name_key(name)
                owner = owner_by_name.get(key)
                if not key or (owner is not None and owner != item["id"]):
                    raise ValueError("an exact name is empty or belongs to multiple ingredients")
                owner_by_name[key] = item["id"]

        ambiguous_terms = catalog.get("ambiguousTerms", [])
        if not isinstance(ambiguous_terms, list):
            raise ValueError("ambiguousTerms must be an array")
        ambiguous_by_name: set[str] = set()
        for term in ambiguous_terms:
            if not isinstance(term, Mapping):
                raise ValueError("ambiguous term must be an object")
            terms = term.get("terms")
            candidates = term.get("candidateIDs")
            if (
                not isinstance(terms, list)
                or not isinstance(candidates, list)
                or len(set(candidates)) < 2
                or any(not isinstance(value, str) or value not in known_ids for value in candidates)
            ):
                raise ValueError("ambiguous term has invalid candidates")
            for name in terms:
                if not isinstance(name, str) or not _name_key(name):
                    raise ValueError("ambiguous term names must be nonempty strings")
                key = _name_key(name)
                if key in owner_by_name or key in ambiguous_by_name:
                    raise ValueError("ambiguous term conflicts with another catalog name")
                ambiguous_by_name.add(key)
    except (KeyError, TypeError, ValueError, ProductInputError) as error:
        raise IngredientAliasCatalogError("active_alias_catalog_invalid") from error


def _name_key(value: str) -> str:
    return " ".join("".join(char.lower() if char.isalnum() else " " for char in value).split())
