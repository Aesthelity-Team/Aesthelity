"""Firestore-backed API for the Aesthelity iOS analysis demo.

Run from the repository root with ``python Backend/analysis_api.py``.
Local demo mode is intentionally loopback-only and skips ID-token verification;
all non-demo runs require a verified Firebase ID token for analysis requests.
"""

from __future__ import annotations

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from analysis_engine import AnalysisInputError, evaluate_routine  # noqa: E402
from analysis_engine.product_input import ProductInputError, load_alias_catalog  # noqa: E402
from Backend.private_data import PrivateDataStore, PrivateDataError
from Backend.authentication import verified_firebase_uid  # noqa: E402
from Backend.ingredient_alias_store import load_approved_alias_catalog  # noqa: E402
from Backend.ingredient_catalog import (  # noqa: E402
    IngredientCatalogError,
    load_reference_index,
    resolve_ingredient_texts,
)


CATALOG_PATH = ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"
MAX_BODY_BYTES = 1_000_000
RULE_VERSION = "AN-02-v1"

PRODUCT_FIELDS = (
    "brand",
    "category",
    "subtype",
    "ingredients",
    "ingredient_list_status",
    "is_fictional",
    "name",
    "provenance",
    "source_ref",
    "source_url",
    "spf",
    "verified_on",
)


def _camel_product(document_id: str, raw: dict[str, Any]) -> dict[str, Any]:
    if raw.get("id") != document_id:
        raise ValueError(f"Product {document_id!r} has a mismatched id field.")
    missing = [field for field in PRODUCT_FIELDS if field not in raw]
    if missing:
        raise ValueError(f"Product {document_id!r} is missing required fields: {', '.join(missing)}.")
    provenance = raw.get("provenance")
    if not isinstance(provenance, dict):
        raise ValueError(f"Product {document_id!r} has invalid provenance.")
    return {
        "id": document_id,
        "brand": raw["brand"],
        "category": raw["category"],
        "subtype": raw["subtype"],
        "ingredients": raw["ingredients"],
        "ingredientListStatus": raw["ingredient_list_status"],
        "isFictional": raw["is_fictional"],
        "name": raw["name"],
        "provenance": {
            "kind": provenance.get("kind"),
            "verificationMethod": provenance.get("verification_method"),
            "note": provenance.get("note"),
        },
        "sourceRef": raw["source_ref"],
        "sourceUrl": raw["source_url"],
        "spf": raw["spf"],
        "verifiedOn": raw["verified_on"],
    }


def _error_body(code: str, message: str, request_id: str | None = None) -> dict[str, Any]:
    return {
        "error": {
            "code": code,
            "message": message,
            "fieldErrors": [],
            "requestID": request_id or str(uuid4()),
        }
    }


class APIHandler(BaseHTTPRequestHandler):
    server_version = "AesthelityAnalysis/1.0"

    def __init__(self, *args: Any, **kwargs: Any):
        self.authenticated_uid: str | None = None
        super().__init__(*args, **kwargs)

    def do_GET(self) -> None:
        if self._private_route():
            return
        route = urlparse(self.path)
        if route.path == "/health":
            catalog, catalog_source = load_approved_alias_catalog(
                self.server.db, self.server.catalog
            )
            self._send(200, {
                "status": "ready",
                "contractVersion": 1,
                "activeCatalogVersion": catalog["version"],
                "catalogSource": catalog_source,
                "referenceCatalogVersion": getattr(self._reference_index(), "version", None),
                "firestoreDatabase": self.server.database_id,
            })
        elif route.path == "/api/v1/ingredient-aliases":
            catalog, catalog_source = load_approved_alias_catalog(
                self.server.db, self.server.catalog
            )
            self._send(200, {**catalog, "catalogSource": catalog_source})
        elif route.path.startswith("/api/v1/ingredients/"):
            self._get_ingredient(unquote(route.path.rsplit("/", 1)[-1]))
        elif route.path == "/api/v1/products":
            self._list_products()
        elif route.path.startswith("/api/v1/products/"):
            self._get_product(unquote(route.path.rsplit("/", 1)[-1]))
        else:
            self._send(404, _error_body("NOT_FOUND", "Route not found."))

    def do_POST(self) -> None:
        if self._private_route():
            return
        path = urlparse(self.path).path
        if path not in {"/api/v1/analyses", "/api/v1/ingredients/resolve"}:
            self._send(404, _error_body("NOT_FOUND", "Route not found."))
            return
        if not self._authorized():
            self._send(401, _error_body("UNAUTHENTICATED", "A valid Firebase ID token is required."))
            return
        if self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower() != "application/json":
            self._send(400, _error_body("INVALID_REQUEST", "Content-Type must be application/json."))
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BODY_BYTES:
            self._send(400, _error_body("INVALID_REQUEST", "Request body is empty or too large."))
            return
        try:
            payload = json.loads(self.rfile.read(length))
        except (json.JSONDecodeError, UnicodeDecodeError):
            self._send(400, _error_body("INVALID_REQUEST", "Request body must be valid UTF-8 JSON."))
            return
        if not isinstance(payload, dict) or payload.get("contractVersion") != 1:
            self._send(400, _error_body("INVALID_REQUEST", "contractVersion must be 1."))
            return
        if path == "/api/v1/ingredients/resolve":
            self._resolve_ingredients(payload)
            return
        try:
            catalog, catalog_source = load_approved_alias_catalog(
                self.server.db, self.server.catalog
            )
            result = evaluate_routine(payload, catalog)
        except (AnalysisInputError, ProductInputError, TypeError, ValueError) as error:
            code = error.code if isinstance(error, AnalysisInputError) else "INVALID_REQUEST"
            self._send(400, _error_body(code, str(error)))
            return
        self._send(200, {
            "contractVersion": 1,
            "ruleVersion": RULE_VERSION,
            "catalogSource": catalog_source,
            **result,
        })

    def do_PUT(self) -> None:
        if not self._private_route():
            self._send(404, _error_body("NOT_FOUND", "Route not found."))

    def do_DELETE(self) -> None:
        if not self._private_route():
            self._send(404, _error_body("NOT_FOUND", "Route not found."))

    def _private_route(self) -> bool:
        path = urlparse(self.path).path
        if not (path == "/api/v1/users" or path.startswith("/api/v1/users/")):
            return False
        # Private storage NEVER inherits the fictional demo authentication bypass.
        self.authenticated_uid = None
        try:
            verifier = getattr(self.server, "token_verifier", None)
            if verifier is None:
                from firebase_admin import auth
                verifier = lambda token: auth.verify_id_token(
                    token, app=self.server.firebase_app, check_revoked=True)
            uid = verified_firebase_uid(self.headers.get("Authorization"), verifier)
            if not uid:
                raise PrivateDataError(401, "UNAUTHENTICATED", "Sign in is required.")
            parts = path.split("/")
            if len(parts) not in {6, 7} or any(not part for part in parts[1:]):
                raise PrivateDataError(404, "NOT_FOUND", "Route not found.")
            owner, kind = unquote(parts[4]), unquote(parts[5])
            record_id = unquote(parts[6]) if len(parts) == 7 else None
            store = PrivateDataStore(self.server.db)
            # Authorize before parsing a body or performing any database access.
            store.collection(uid, owner, kind)
            payload = None
            if self.command == "PUT":
                if self.headers.get("Transfer-Encoding") or self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower() != "application/json":
                    raise PrivateDataError(400, "INVALID_REQUEST", "JSON body required.")
                try:
                    length = int(self.headers.get("Content-Length", "0"))
                    if not 0 < length <= MAX_BODY_BYTES:
                        raise ValueError()
                    payload = json.loads(self.rfile.read(length))
                except (ValueError, UnicodeError, RecursionError):
                    raise PrivateDataError(400, "INVALID_REQUEST", "Invalid JSON body.") from None
            result = store.execute(uid, owner, kind, record_id, self.command, payload)
            self._send(200, {"contractVersion": 1, **result})
        except PrivateDataError as error:
            self._send(error.status, _error_body(error.code, str(error)))
        except Exception:
            self._send(503, _error_body("SERVICE_UNAVAILABLE", "Private data is temporarily unavailable."))
        return True

    def _authorized(self) -> bool:
        if self.server.demo_mode:
            return True

        def verify_token(token: str) -> dict[str, Any]:
            from firebase_admin import auth
            return auth.verify_id_token(token, app=self.server.firebase_app)

        try:
            self.authenticated_uid = verified_firebase_uid(
                self.headers.get("Authorization"), verify_token
            )
        except Exception:
            # Treat SDK/import/configuration errors as unavailable auth. Never
            # let an infrastructure error turn a protected request public.
            self.authenticated_uid = None
            return False
        return self.authenticated_uid is not None

    def _reference_index(self) -> Any:
        index = getattr(self.server, "reference_index", None)
        if index is None:
            index = load_reference_index(self.server.catalog)
            self.server.reference_index = index
        return index

    def _resolve_ingredients(self, payload: dict[str, Any]) -> None:
        """Resolve raw label strings against the approved + full CosIng catalog.

        Approved-catalog matches are `confirmed`; reference-only matches are
        `uncertain` with a suggestedID, so PD-03 keeps them out of analysis.
        """
        catalog, catalog_source = load_approved_alias_catalog(self.server.db, self.server.catalog)
        reference = self._reference_index()
        try:
            rows = resolve_ingredient_texts(
                payload.get("ingredients"), catalog, reference, db=self.server.db
            )
        except IngredientCatalogError as error:
            self._send(400, _error_body("INVALID_REQUEST", str(error)))
            return
        self._send(200, {
            "contractVersion": 1,
            "activeCatalogVersion": catalog["version"],
            "catalogSource": catalog_source,
            "referenceCatalogVersion": getattr(reference, "version", None),
            "ingredients": rows,
            "uncertaintyPreserved": any(row["mapping"] != "confirmed" for row in rows),
        })

    def _get_ingredient(self, ingredient_id: str) -> None:
        reference = self._reference_index()
        record = reference.records.get(ingredient_id) if reference and ingredient_id else None
        if record is None:
            self._send(404, _error_body("INGREDIENT_NOT_FOUND", "The ingredient was not found."))
            return
        self._send(200, {
            "contractVersion": 1,
            "referenceCatalogVersion": reference.version,
            "ingredient": {key: value for key, value in record.items() if key not in {"name", "aliasKeys"}},
        })

    def _list_products(self) -> None:
        try:
            documents = sorted(self.server.db.collection("products").stream(), key=lambda doc: doc.id)
            products = [_camel_product(document.id, document.to_dict() or {}) for document in documents]
        except Exception as error:
            print(f"Firestore catalog read failed: {type(error).__name__}: {error}")
            self._send(500, _error_body("INTERNAL_ERROR", "The product catalog could not be loaded."))
            return
        self._send(200, {"contractVersion": 1, "products": products})

    def _get_product(self, product_id: str) -> None:
        if not product_id or "/" in product_id:
            self._send(404, _error_body("PRODUCT_NOT_FOUND", "The product was not found."))
            return
        try:
            document = self.server.db.collection("products").document(product_id).get()
            if not document.exists:
                self._send(404, _error_body("PRODUCT_NOT_FOUND", "The product was not found."))
                return
            product = _camel_product(document.id, document.to_dict() or {})
        except Exception as error:
            print(f"Firestore product read failed: {type(error).__name__}: {error}")
            self._send(500, _error_body("INTERNAL_ERROR", "The product could not be loaded."))
            return
        self._send(200, {"contractVersion": 1, "product": product})

    def _send(self, status: int, body: dict[str, Any]) -> None:
        encoded = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format: str, *args: Any) -> None:
        print(f"{self.address_string()} {format % args}")


class AnalysisHTTPServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], *, db: Any, app: Any, catalog: dict[str, Any], database_id: str, demo_mode: bool):
        super().__init__(address, APIHandler)
        self.db = db
        self.firebase_app = app
        self.catalog = catalog
        self.database_id = database_id
        self.demo_mode = demo_mode
        self.reference_index = None


def main() -> None:
    project_id = os.environ.get("FIREBASE_PROJECT_ID", "aesthelity-2026")
    database_id = os.environ.get("FIRESTORE_DATABASE_ID", "ogdb")
    host = os.environ.get("AESTHELITY_API_HOST", "127.0.0.1")
    port = int(os.environ.get("AESTHELITY_API_PORT", "8765"))
    demo_mode = os.environ.get("AESTHELITY_DEMO_MODE", "0").lower() in {"1", "true", "yes"}
    if demo_mode and host not in {"127.0.0.1", "localhost", "::1"}:
        raise SystemExit("AESTHELITY_DEMO_MODE may only bind to loopback.")

    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError as error:
        raise SystemExit("Install Backend/requirements.txt before starting the API.") from error

    catalog = load_alias_catalog(CATALOG_PATH)
    reference_index = load_reference_index(catalog)
    app = firebase_admin.initialize_app(
        credentials.ApplicationDefault(),
        {"projectId": project_id},
    )
    db = firestore.client(app=app, database_id=database_id)
    server = AnalysisHTTPServer(
        (host, port), db=db, app=app, catalog=catalog,
        database_id=database_id, demo_mode=demo_mode,
    )
    server.reference_index = reference_index
    print(f"API listening at http://{host}:{port}")
    print(f"Firestore: project={project_id}, database={database_id}, collection=products")
    print(
        f"Bundled alias fallback version: {catalog['version']}; "
        "active alias source: ingredientAliasCatalogs/active; "
        f"analysis rules: {RULE_VERSION}"
    )
    if reference_index is None:
        print("Full ingredient catalog: unavailable (Backend/data/cosing_ingredients.json.gz missing or invalid)")
    else:
        print(f"Full ingredient catalog: {reference_index.version}, {len(reference_index.records)} ingredients")
    print("Auth: local demo bypass" if demo_mode else "Auth: Firebase ID token required for analysis")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Stopping Aesthelity analysis API.")
    finally:
        server.server_close()
        firebase_admin.delete_app(app)


if __name__ == "__main__":
    main()

