"""Full cosmetic ingredient reference catalog (EU CosIng) and its resolver.

The approved alias catalog (`ingredient-aliases.json` /
`ingredientAliasCatalogs/active`) stays the hand-reviewed source of truth for
AN-02 analysis. This module layers the complete EU CosIng ingredient inventory
underneath it:

* hand-approved IDs, names, aliases, classes and ambiguous terms always win;
* every CosIng INCI name gets a deterministic canonical ID (slug of the INCI
  name, collision-safe) unless it is the same ingredient as an approved entry,
  in which case it keeps the approved ID;
* lookups never guess: a name either resolves to exactly one ID, is ambiguous
  (two or more candidate IDs), or stays unknown.

Reference-tier matches are identified ingredients, but they are not members of
the approved analysis catalog. Under PD-03 they are returned as `uncertain`
with a `suggestedID`, so products containing them stay out of rule analysis
until the ingredient is promoted into the approved catalog.
"""

from __future__ import annotations

import csv
import gzip
import hashlib
import io
import json
import re
import unicodedata
from collections import defaultdict
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any


SOURCE_NAME = "EU CosIng"
SOURCE_URL = "https://ec.europa.eu/growth/tools-databases/cosing/"
DETAIL_URL = "https://ec.europa.eu/growth/tools-databases/cosing/details/{ref}"
DATA_PATH = Path(__file__).resolve().parent / "data" / "cosing_ingredients.json.gz"

INGREDIENTS_COLLECTION = "ingredients"
AMBIGUOUS_COLLECTION = "ingredientAmbiguousTerms"
META_COLLECTION = "ingredientCatalogs"
META_DOCUMENT = "reference"

MAX_SLUG_LENGTH = 100
MAX_AMBIGUOUS_CANDIDATES = 10
MAX_RESOLVE_TEXTS = 200
MAX_TEXT_LENGTH = 500

_ID = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
_CAS = re.compile(r"\b(\d{2,7}-\d{2}-\d)\b")
_EC = re.compile(r"\b(\d{3}-\d{3}-\d)\b")
_BRACKETED = re.compile(r"\s*\[[^\]]*\]\s*")
_CSV_HEADER = "COSING Ref No"
_PARENTHETICAL = re.compile(r"\([^()]*\)")
_PARENTHETICAL_INNER = re.compile(r"\(([^()]*)\)")


class IngredientCatalogError(ValueError):
    """The source export or generated catalog is invalid."""


def name_key(value: str) -> str:
    """Same exact-name key as the approved catalog and the Swift normalizer."""

    return " ".join("".join(char.lower() if char.isalnum() else " " for char in value).split())


def slugify(value: str) -> str:
    ascii_value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    return "-".join(re.findall(r"[a-z0-9]+", ascii_value.lower()))


def _short_hash(value: str) -> str:
    return hashlib.sha1(value.encode("utf-8")).hexdigest()[:8]


def _ref_sort_key(ref: str) -> tuple[int, str]:
    return (int(ref), ref) if ref.isdigit() else (10**12, ref)


# --------------------------------------------------------------------------
# Source rows
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class SourceRow:
    """One CosIng inventory entry, reduced to the fields Aesthelity keeps."""

    ref_no: str
    inci_name: str
    inn_names: tuple[str, ...] = ()
    ph_eur_names: tuple[str, ...] = ()
    usa_names: tuple[str, ...] = ()
    cas_numbers: tuple[str, ...] = ()
    ec_numbers: tuple[str, ...] = ()
    description: str = ""
    restrictions: tuple[str, ...] = ()
    functions: tuple[str, ...] = ()
    status: str | None = None
    published: bool | None = None
    update_date: str | None = None

    def to_json(self) -> dict[str, Any]:
        return {
            "refNo": self.ref_no,
            "inciName": self.inci_name,
            "innNames": list(self.inn_names),
            "phEurNames": list(self.ph_eur_names),
            "usaNames": list(self.usa_names),
            "casNumbers": list(self.cas_numbers),
            "ecNumbers": list(self.ec_numbers),
            "description": self.description,
            "restrictions": list(self.restrictions),
            "functions": list(self.functions),
            "status": self.status,
            "published": self.published,
            "updateDate": self.update_date,
        }

    @classmethod
    def from_json(cls, value: Mapping[str, Any]) -> "SourceRow":
        return cls(
            ref_no=str(value["refNo"]),
            inci_name=_clean(value["inciName"]),
            inn_names=tuple(value.get("innNames") or ()),
            ph_eur_names=tuple(value.get("phEurNames") or ()),
            usa_names=tuple(value.get("usaNames") or ()),
            cas_numbers=tuple(value.get("casNumbers") or ()),
            ec_numbers=tuple(value.get("ecNumbers") or ()),
            description=value.get("description") or "",
            restrictions=tuple(value.get("restrictions") or ()),
            functions=tuple(value.get("functions") or ()),
            status=value.get("status"),
            published=value.get("published"),
            update_date=value.get("updateDate"),
        )


def _clean(value: Any) -> str:
    return " ".join(str(value or "").split())


def _split_names(values: Iterable[str]) -> tuple[str, ...]:
    names: list[str] = []
    for value in values:
        for part in str(value or "").split(";"):
            part = _clean(_BRACKETED.sub(" ", part))
            if part and part != "-" and part not in names:
                names.append(part)
    return tuple(names)


def _numbers(pattern: re.Pattern[str], values: Iterable[str]) -> tuple[str, ...]:
    found: list[str] = []
    for value in values:
        for number in pattern.findall(str(value or "")):
            if number not in found:
                found.append(number)
    return tuple(found)


def _functions(values: Iterable[str]) -> tuple[str, ...]:
    found: list[str] = []
    for value in values:
        for part in str(value or "").split(","):
            part = _clean(part).upper()
            if part and part not in found:
                found.append(part)
    return tuple(found)


def _restrictions(values: Iterable[str]) -> tuple[str, ...]:
    found: list[str] = []
    for value in values:
        for part in re.split(r"[\r\n,]+", str(value or "")):
            part = _clean(part)
            if part and part not in found:
                found.append(part)
    return tuple(found)


def parse_cosing_csv(text: str) -> list[SourceRow]:
    """Parse the classic CosIng "Ingredients/Fragrance Inventory" CSV export.

    The export starts with a few preamble lines (``sep=,``, creation date)
    before the header row that begins with ``COSING Ref No``.
    """

    lines = text.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.lstrip("\ufeff\" ").startswith(_CSV_HEADER)), None)
    if start is None:
        raise IngredientCatalogError("CosIng CSV header row (COSING Ref No, INCI name, ...) not found.")
    reader = csv.DictReader(io.StringIO("".join(lines[start:])))
    rows: list[SourceRow] = []
    for raw in reader:
        raw = {(_clean(k) if k else ""): v for k, v in raw.items()}
        ref = _clean(raw.get("COSING Ref No"))
        inci = _clean(raw.get("INCI name"))
        if not ref or not inci:
            continue
        rows.append(
            SourceRow(
                ref_no=ref,
                inci_name=inci,
                inn_names=_split_names([raw.get("INN name", "")]),
                ph_eur_names=_split_names([raw.get("Ph. Eur. Name", "")]),
                cas_numbers=_numbers(_CAS, [raw.get("CAS No", "")]),
                ec_numbers=_numbers(_EC, [raw.get("EINECS/ELINCS No", "")]),
                description=_clean(raw.get("Chem/IUPAC Name / Description")),
                restrictions=_restrictions([raw.get("Restriction", "")]),
                functions=_functions([raw.get("Function", "")]),
                update_date=_clean(raw.get("Update Date")) or None,
            )
        )
    return rows


def row_from_search_metadata(metadata: Mapping[str, Any]) -> SourceRow | None:
    """Convert one record from the CosIng public search service."""

    def values(key: str) -> list[str]:
        raw = metadata.get(key) or []
        return [str(v) for v in (raw if isinstance(raw, list) else [raw])]

    ref = _clean((values("substanceId") or [""])[0])
    inci = _clean((values("inciName") or [""])[0])
    if not ref or not inci:
        return None
    status = _clean((values("status") or [""])[0]) or None
    published = (values("officialJournalPublication") or [None])[0]
    return SourceRow(
        ref_no=ref,
        inci_name=inci,
        inn_names=_split_names(values("innName")),
        ph_eur_names=_split_names(values("phEurName")),
        usa_names=_split_names(values("inciUsaName")),
        cas_numbers=_numbers(_CAS, values("casNo")),
        ec_numbers=_numbers(_EC, values("ecNo")),
        description=_clean(" ".join(values("chemicalDescription"))),
        restrictions=_restrictions(values("cosmeticRestriction")),
        functions=_functions(values("functionName")),
        status=status,
        published=None if published is None else published == "Y",
    )


def load_source(path: str | Path) -> tuple[dict[str, Any], list[SourceRow]]:
    """Load a committed snapshot (``.json`` / ``.json.gz``) or a CosIng CSV export."""

    source = Path(path)
    raw = source.read_bytes()
    name = source.name.lower()
    if name.endswith(".gz"):
        raw = gzip.decompress(raw)
        name = name[:-3]
    if not name.endswith(".json"):
        for encoding in ("utf-8-sig", "cp1252", "latin-1"):
            try:
                text = raw.decode(encoding)
                break
            except UnicodeDecodeError:
                continue
        rows = parse_cosing_csv(text)
        return {"source": SOURCE_NAME, "sourceUrl": SOURCE_URL, "sourceFile": source.name}, rows
    document = json.loads(raw.decode("utf-8"))
    meta = {key: value for key, value in document.items() if key != "rows"}
    return meta, [SourceRow.from_json(row) for row in document.get("rows", [])]


def write_snapshot(path: str | Path, meta: Mapping[str, Any], rows: Iterable[SourceRow]) -> None:
    ordered = sorted(rows, key=lambda row: _ref_sort_key(row.ref_no))
    document = {**meta, "rowCount": len(ordered), "rows": [row.to_json() for row in ordered]}
    payload = json.dumps(document, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    # mtime=0 keeps the gzip bytes reproducible for identical content.
    with open(target, "wb") as handle, gzip.GzipFile(filename="", fileobj=handle, mode="wb", mtime=0, compresslevel=9) as gz:
        gz.write(payload)


# --------------------------------------------------------------------------
# Catalog build
# --------------------------------------------------------------------------


@dataclass
class _Group:
    key: str
    rows: list[SourceRow] = field(default_factory=list)

    @property
    def first(self) -> SourceRow:
        return self.rows[0]

    @property
    def min_ref(self) -> tuple[int, str]:
        return _ref_sort_key(self.first.ref_no)

    def synonyms(self) -> list[tuple[str, str]]:
        found: list[tuple[str, str]] = []
        for row in self.rows:
            for kind, names in (("inci-usa-name", row.usa_names), ("inn-name", row.inn_names), ("ph-eur-name", row.ph_eur_names)):
                found.extend((kind, name) for name in names)
        return found


def build_catalog(
    rows: Iterable[SourceRow],
    approved_catalog: Mapping[str, Any],
    *,
    version: str = "cosing",
    include_inactive: bool = False,
) -> dict[str, Any]:
    """Build the full canonical ingredient catalog.

    Deterministic for the same input: records are grouped by exact INCI name,
    groups are processed in CosIng reference-number order, and the lowest
    reference number keeps the plain slug when two INCI names slug the same.
    """

    stats: dict[str, Any] = defaultdict(int)
    approved_items = list(approved_catalog.get("ingredients", []))
    approved_by_id = {item["id"]: item for item in approved_items}
    approved_owner: dict[str, str] = {}
    for item in approved_items:
        for name in [item["name"], *item.get("aliases", [])]:
            approved_owner[name_key(name)] = item["id"]
    approved_ambiguous: dict[str, list[str]] = {}
    for term in approved_catalog.get("ambiguousTerms", []):
        for name in term.get("terms", []):
            approved_ambiguous[name_key(name)] = list(term["candidateIDs"])

    # 1. Group rows by exact INCI name (duplicate INCI rows are one ingredient).
    groups: dict[str, _Group] = {}
    for row in rows:
        stats["sourceRows"] += 1
        if row.status and row.status.lower() not in {"active"} and not include_inactive:
            stats["skippedInactive"] += 1
            continue
        key = name_key(row.inci_name)
        if not key:
            stats["skippedEmptyName"] += 1
            continue
        groups.setdefault(key, _Group(key)).rows.append(row)
    for group in groups.values():
        group.rows.sort(key=lambda row: _ref_sort_key(row.ref_no))
        if len(group.rows) > 1:
            stats["duplicateInciRowsMerged"] += len(group.rows) - 1
    ordered = sorted(groups.values(), key=lambda group: (group.min_ref, group.key))

    # 2. Attach groups to approved IDs (approved IDs never change).
    group_id: dict[str, str] = {}
    synonym_merges: list[dict[str, str]] = []
    for group in ordered:
        if group.key in approved_owner:
            group_id[group.key] = approved_owner[group.key]
            stats["mappedToApprovedByName"] += 1
            continue
        if group.key in approved_ambiguous:
            stats["inciNamesReservedAsAmbiguous"] += 1
        matches = {approved_owner[name_key(name)] for _, name in group.synonyms() if name_key(name) in approved_owner}
        if len(matches) == 1:
            approved_id = matches.pop()
            group_id[group.key] = approved_id
            stats["mappedToApprovedBySynonym"] += 1
            synonym_merges.append({"inciName": group.first.inci_name, "approvedID": approved_id})
        elif len(matches) > 1:
            stats["approvedSynonymConflicts"] += 1

    # 3. Deterministic, collision-safe IDs for everything else.
    taken: set[str] = set(approved_by_id)
    for group in ordered:
        if group.key in group_id:
            continue
        base = slugify(group.first.inci_name) or "ingredient"
        candidate = base
        if len(candidate) > MAX_SLUG_LENGTH:
            candidate = base[:MAX_SLUG_LENGTH].rstrip("-") + "-" + _short_hash(group.key)
            stats["longSlugsShortened"] += 1
        if candidate in taken:
            candidate = base[: MAX_SLUG_LENGTH].rstrip("-") + "-" + _short_hash(group.key)
            stats["slugCollisionsSuffixed"] += 1
        if not _ID.fullmatch(candidate) or candidate in taken:
            raise IngredientCatalogError(f"Could not assign a unique ID for {group.first.inci_name!r}.")
        taken.add(candidate)
        group_id[group.key] = candidate

    groups_by_id: dict[str, list[_Group]] = defaultdict(list)
    for group in ordered:
        groups_by_id[group_id[group.key]].append(group)

    # 4. Exact-name lookup ownership. Priority: approved names/aliases, approved
    #    ambiguous terms, CosIng INCI names, then CosIng synonyms.
    owner: dict[str, str] = dict(approved_owner)
    display: dict[str, str] = {}
    for item in approved_items:
        for name in [item["name"], *item.get("aliases", [])]:
            display.setdefault(name_key(name), name)
    ambiguous: dict[str, list[str]] = dict(approved_ambiguous)
    for group in ordered:
        ingredient_id = group_id[group.key]
        if group.key in ambiguous:
            continue
        existing = owner.get(group.key)
        if existing is None:
            owner[group.key] = ingredient_id
            display[group.key] = group.first.inci_name
        elif existing != ingredient_id:
            stats["inciNameConflictsDropped"] += 1

    synonym_owners: dict[str, set[str]] = defaultdict(set)
    synonym_display: dict[str, str] = {}
    for group in ordered:
        for _, name in group.synonyms():
            key = name_key(name)
            if not key:
                continue
            synonym_owners[key].add(group_id[group.key])
            synonym_display.setdefault(key, name)
    generated_ambiguous: list[dict[str, Any]] = []
    for key in sorted(synonym_owners):
        ids = synonym_owners[key]
        if key in owner or key in ambiguous:
            if key in owner and ids != {owner[key]}:
                stats["synonymsShadowedByOtherNames"] += 1
            continue
        if len(ids) == 1:
            owner[key] = next(iter(ids))
            display[key] = synonym_display[key]
            stats["synonymAliases"] += 1
        elif len(ids) <= MAX_AMBIGUOUS_CANDIDATES:
            candidates = sorted(ids)
            ambiguous[key] = candidates
            generated_ambiguous.append(
                {
                    "terms": [synonym_display[key]],
                    "candidateIDs": candidates,
                    "note": f"{SOURCE_NAME} lists this name for several INCI entries.",
                    "source": SOURCE_NAME,
                }
            )
            stats["generatedAmbiguousTerms"] += 1
        else:
            stats["synonymsDroppedTooManyCandidates"] += 1

    keys_by_id: dict[str, list[str]] = defaultdict(list)
    for key, ingredient_id in owner.items():
        keys_by_id[ingredient_id].append(key)

    # 5. Records.
    records: list[dict[str, Any]] = []
    all_ids = sorted(set(approved_by_id) | set(groups_by_id))
    for ingredient_id in all_ids:
        approved = approved_by_id.get(ingredient_id)
        id_groups = groups_by_id.get(ingredient_id, [])
        source_rows = sorted((row for group in id_groups for row in group.rows), key=lambda row: _ref_sort_key(row.ref_no))
        canonical = approved["name"] if approved else source_rows[0].inci_name
        aliases: list[str] = list(approved.get("aliases", [])) if approved else []
        owned = set(keys_by_id.get(ingredient_id, []))
        listed = {name_key(canonical), *(name_key(alias) for alias in aliases)}
        for key in sorted(owned):
            if key not in listed:
                aliases.append(display[key])
                listed.add(key)
        # Only names this ingredient owns are searchable; a canonical name that
        # is an approved ambiguous term (e.g. "BHA") stays unsearchable.
        alias_keys = owned
        record: dict[str, Any] = {
            "id": ingredient_id,
            "canonicalName": canonical,
            "name": canonical,
            "inciNames": _unique(row.inci_name for row in source_rows),
            "aliases": aliases,
            "aliasKeys": sorted(alias_keys),
            "classes": list(approved.get("classes", [])) if approved else [],
            "tier": "approved" if approved else "reference",
            "casNumbers": _unique(n for row in source_rows for n in row.cas_numbers),
            "ecNumbers": _unique(n for row in source_rows for n in row.ec_numbers),
            "functions": _unique(f for row in source_rows for f in row.functions),
            "description": next((row.description for row in source_rows if row.description), ""),
            "restrictions": _unique(r for row in source_rows for r in row.restrictions),
            "sources": [
                {"source": SOURCE_NAME, "refNo": row.ref_no, "url": DETAIL_URL.format(ref=row.ref_no)}
                for row in source_rows
            ],
        }
        if approved and approved.get("references"):
            record["references"] = approved["references"]
        records.append(record)

    stats["ingredients"] = len(records)
    stats["approvedTier"] = sum(1 for r in records if r["tier"] == "approved")
    stats["approvedWithCosingData"] = sum(1 for r in records if r["tier"] == "approved" and r["sources"])
    stats["referenceTier"] = stats["ingredients"] - stats["approvedTier"]
    stats["lookupNames"] = len(owner)
    stats["aliases"] = sum(len(r["aliases"]) for r in records)
    stats["ambiguousTerms"] = len(ambiguous)
    return {
        "version": version,
        "ingredients": records,
        "ambiguousTerms": list(approved_catalog.get("ambiguousTerms", [])) + generated_ambiguous,
        "synonymMergesForReview": synonym_merges,
        "stats": dict(sorted(stats.items())),
    }


def _unique(values: Iterable[str]) -> list[str]:
    found: list[str] = []
    for value in values:
        if value and value not in found:
            found.append(value)
    return found


# --------------------------------------------------------------------------
# Resolver
# --------------------------------------------------------------------------


class ReferenceIndex:
    """In-memory exact-name, ambiguous-term and CAS index of the full catalog."""

    def __init__(self, catalog: Mapping[str, Any], meta: Mapping[str, Any] | None = None):
        self.version = catalog.get("version")
        self.meta = dict(meta or {})
        self.records: dict[str, dict[str, Any]] = {r["id"]: r for r in catalog["ingredients"]}
        self.owner: dict[str, str] = {}
        self.ambiguous: dict[str, list[str]] = {}
        self.cas: dict[str, list[str]] = defaultdict(list)
        for record in catalog["ingredients"]:
            for key in record.get("aliasKeys", []):
                self.owner[key] = record["id"]
            for number in record.get("casNumbers", []):
                self.cas[number].append(record["id"])
        for term in catalog.get("ambiguousTerms", []):
            for name in term["terms"]:
                self.ambiguous[name_key(name)] = list(term["candidateIDs"])
        self.stats = dict(catalog.get("stats", {}))

    def lookup(self, text: str) -> tuple[str, list[str], str | None]:
        """Return (kind, ids, matchedOn) with kind in resolved/ambiguous/unknown."""

        key = name_key(text)
        if not key:
            return "unknown", [], None
        if key in self.ambiguous:
            return "ambiguous", list(self.ambiguous[key]), "ambiguous-term"
        if key in self.owner:
            return "resolved", [self.owner[key]], "name"
        stripped = text.strip()
        if _CAS.fullmatch(stripped):
            ids = self.cas.get(stripped, [])
            if len(ids) == 1:
                return "resolved", ids, "cas-number"
            if len(ids) > 1:
                return "ambiguous", sorted(ids)[:MAX_AMBIGUOUS_CANDIDATES], "cas-number"
        return "unknown", [], None


def build_reference_index(
    approved_catalog: Mapping[str, Any], source_path: str | Path = DATA_PATH
) -> ReferenceIndex:
    meta, rows = load_source(source_path)
    catalog = build_catalog(rows, approved_catalog, version=_version_from_meta(meta))
    return ReferenceIndex(catalog, meta)


def _version_from_meta(meta: Mapping[str, Any]) -> str:
    retrieved = meta.get("retrievedOn")
    return f"cosing-{retrieved}" if retrieved else "cosing"


@lru_cache(maxsize=2)
def _cached_index(source_path: str, approved_json: str) -> ReferenceIndex:
    return build_reference_index(json.loads(approved_json), source_path)


def load_reference_index(
    approved_catalog: Mapping[str, Any], source_path: str | Path = DATA_PATH
) -> ReferenceIndex | None:
    """Cached index; returns None if the generated data file is missing or invalid."""

    try:
        return _cached_index(str(source_path), json.dumps(approved_catalog, sort_keys=True))
    except (OSError, ValueError, KeyError, IngredientCatalogError):
        return None


def firestore_alias_lookup(db: Any, key: str) -> list[str]:
    """IDs from the Firestore `ingredients` collection whose aliasKeys contain key."""

    collection = db.collection(INGREDIENTS_COLLECTION)
    try:
        from google.cloud.firestore_v1.base_query import FieldFilter
    except ImportError:
        query = collection.where("aliasKeys", "array_contains", key)
    else:
        query = collection.where(filter=FieldFilter("aliasKeys", "array_contains", key))
    query = query.limit(MAX_AMBIGUOUS_CANDIDATES + 1)
    return sorted({snapshot.id for snapshot in query.stream()})


def resolve_ingredient_texts(
    texts: Any,
    approved_catalog: Mapping[str, Any],
    reference: ReferenceIndex | None,
    *,
    db: Any = None,
    max_firestore_lookups: int = 25,
) -> list[dict[str, Any]]:
    """Resolve raw label strings without guessing.

    Order: approved catalog (exact names and ambiguous terms), the full
    reference index, then the Firestore `ingredients` collection for names the
    bundled data does not know. Original text and order are preserved.
    """

    if not isinstance(texts, list) or len(texts) > MAX_RESOLVE_TEXTS:
        raise IngredientCatalogError(f"ingredients must be an array of at most {MAX_RESOLVE_TEXTS} strings.")
    if any(not isinstance(text, str) or len(text) > MAX_TEXT_LENGTH for text in texts):
        raise IngredientCatalogError(f"Each ingredient must be a string of at most {MAX_TEXT_LENGTH} characters.")

    approved_ids = {item["id"]: item for item in approved_catalog.get("ingredients", [])}
    approved_owner: dict[str, str] = {}
    for item in approved_ids.values():
        for name in [item["name"], *item.get("aliases", [])]:
            approved_owner[name_key(name)] = item["id"]
    approved_ambiguous = {
        name_key(name): list(term["candidateIDs"])
        for term in approved_catalog.get("ambiguousTerms", [])
        for name in term.get("terms", [])
    }

    budget = [max_firestore_lookups]

    def lookup(text: str) -> tuple[str, list[str], str | None, str | None]:
        key = name_key(text)
        kind, ids, matched_on, source = "unknown", [], None, None
        if not key:
            matched_on = None
        elif key in approved_ambiguous:
            kind, ids, matched_on, source = "ambiguous", approved_ambiguous[key], "ambiguous-term", "approved-catalog"
        elif key in approved_owner:
            kind, ids, matched_on, source = "resolved", [approved_owner[key]], "name", "approved-catalog"
        elif reference is not None:
            kind, ids, matched_on = reference.lookup(text)
            source = "reference-catalog" if kind != "unknown" else None
        if kind == "unknown" and key and db is not None and budget[0] > 0:
            budget[0] -= 1
            try:
                found = firestore_alias_lookup(db, key)
            except Exception:
                found = []
            if len(found) == 1:
                kind, ids, matched_on, source = "resolved", found, "name", "firestore"
            elif len(found) > 1:
                kind, ids, matched_on, source = "ambiguous", found[:MAX_AMBIGUOUS_CANDIDATES], "name", "firestore"
        return kind, ids, matched_on, source

    rows: list[dict[str, Any]] = []
    for index, text in enumerate(texts):
        kind, ids, matched_on, source = lookup(text)
        if kind == "unknown" and "(" in text:
            # US-style labels add a common name in parentheses that the EU INCI
            # name omits: "Butyrospermum Parkii (Shea) Butter", "Water (Aqua)".
            outer = _PARENTHETICAL.sub(" ", text)
            inner = " ".join(_PARENTHETICAL_INNER.findall(text))
            outer_result = lookup(outer) if name_key(outer) else ("unknown", [], None, None)
            inner_result = lookup(inner) if name_key(inner) else ("unknown", [], None, None)
            if outer_result[0] != "unknown":
                kind, ids, matched_on, source = outer_result
                if (
                    kind == "resolved"
                    and inner_result[0] == "resolved"
                    and inner_result[1] != ids
                ):
                    kind, ids = "ambiguous", sorted({*ids, *inner_result[1]})
                matched_on = f"{matched_on}-without-parenthetical"
        rows.append(_row(index, text, kind, ids, matched_on, source, approved_ids, reference))
    return rows


def _row(index, text, kind, ids, matched_on, source, approved_ids, reference) -> dict[str, Any]:
    row: dict[str, Any] = {
        "index": index,
        "originalText": text,
        "status": kind,
        "matchedOn": matched_on,
        "source": source,
        "ingredientID": None,
        "suggestedID": None,
        "candidateIDs": [],
        "canonicalName": None,
        "tier": None,
        "analysisEligible": False,
    }
    if kind == "resolved":
        ingredient_id = ids[0]
        record = reference.records.get(ingredient_id) if reference else None
        approved = approved_ids.get(ingredient_id)
        row["canonicalName"] = approved["name"] if approved else (record or {}).get("canonicalName")
        if approved:
            # Approved catalog member: a confirmed, analysis-eligible match.
            row.update(mapping="confirmed", ingredientID=ingredient_id, tier="approved", analysisEligible=True)
        else:
            # Identified from the reference inventory, not yet approved for
            # AN-02 analysis. PD-03 keeps the product out of analysis.
            row.update(mapping="uncertain", suggestedID=ingredient_id, tier="reference")
        if record:
            row["functions"] = record.get("functions", [])
            row["sources"] = record.get("sources", [])
    elif kind == "ambiguous":
        row.update(mapping="ambiguous", candidateIDs=list(ids))
    else:
        row.update(mapping="unmatched", reason="empty_input" if not name_key(text) else "not_in_catalog")
    return row
