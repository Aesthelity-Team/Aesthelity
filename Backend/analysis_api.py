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

from analysis_engine.product_input import load_alias_catalog  # noqa: E402

from analysis_engine.ai_analysis import (
    AIAnalysisInputError,
    OpenAIAnalysisProvider,
    analyze_normalized_routine,
)
from Backend.analysis_engine.normalization import (
    NormalizationInputError,
    OpenAINormalizationProvider,
    normalize_products,
)
from Backend.analysis_reference_store import (
    AnalysisReferenceStoreError,
    load_approved_analysis_records,
)

CATALOG_PATH = ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"
MAX_BODY_BYTES = 1_000_000

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

    def do_GET(self) -> None:
        route = urlparse(self.path)
        if route.path == "/health":
            self._send(200, {
                "status": "ready",
                "contractVersion": 1,
                "activeCatalogVersion": self.server.catalog["version"],
                "firestoreDatabase": self.server.database_id,
            })
        elif route.path == "/api/v1/products":
            self._list_products()
        elif route.path.startswith("/api/v1/products/"):
            self._get_product(unquote(route.path.rsplit("/", 1)[-1]))
        else:
            self._send(404, _error_body("NOT_FOUND", "Route not found."))

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/api/v1/analyses":
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
        if (
            not isinstance(payload, dict)
            or type(payload.get("contractVersion")) is not int
            or payload["contractVersion"] != 1
        ):
            self._send(400, _error_body("INVALID_REQUEST", "contractVersion must be 1."))
            return
        try:
            contract, reference_records = load_approved_analysis_records(
                self.server.db, payload["contractVersion"]
            )
            rule_version = contract.get("ruleSetVersion")
            if not isinstance(rule_version, str) or not rule_version.strip():
                raise AnalysisReferenceStoreError(
                    "approved_analysis_contract_unavailable"
                )

            raw_products = []
            for product in payload.get("products", []):
                if not isinstance(product, dict):
                    raise NormalizationInputError(
                        "Each product must be an object."
                    )

                rows = product.get("ingredients")
                if not isinstance(rows, list):
                    raise NormalizationInputError(
                        "Each product needs an ingredients array."
                    )

                ingredient_texts = []
                for row in rows:
                    if not isinstance(row, dict):
                        raise NormalizationInputError(
                            "Each ingredient needs its originalText."
                        )
                    original_text = row.get("originalText")
                    if not isinstance(original_text, str):
                        raise NormalizationInputError(
                            "Each ingredient needs its originalText."
                        )
                    ingredient_texts.append(original_text)

                raw_products.append({
                    "productID": product.get("productID"),
                    "listStatus": product.get("listStatus"),
                    "ingredients": ingredient_texts,
                })

            normalization = normalize_products(
                raw_products,
                OpenAINormalizationProvider.from_environment(),
            )
            normalization["canonicalDataVersion"] = self.server.catalog["version"]

            canonical_records = [
                {
                    "id": ingredient["id"],
                    "canonicalName": ingredient["name"],
                    "classes": ingredient.get("classes", []),
                }
                for ingredient in self.server.catalog["ingredients"]
            ]

            allergies = payload.get("recordedAllergies")
            if isinstance(allergies, dict) and allergies.get("status") == "unknown":
                allergies = {"status": "unknown"}

            result = analyze_normalized_routine(
                normalization=normalization,
                routine_context={
                    "period": payload.get("period"),
                    "recordedAllergies": allergies,
                },
                canonical_records=canonical_records,
                reference_records=reference_records,
                provider=OpenAIAnalysisProvider.from_environment(),
            )
        except AnalysisReferenceStoreError:
            self._send(
                503,
                _error_body(
                    "ANALYSIS_DATA_UNAVAILABLE",
                    "Approved analysis data could not be loaded.",
                ),
            )
            return
        except (
            AIAnalysisInputError,
            NormalizationInputError,
            TypeError,
            ValueError,
        ) as error:
            self._send(400, _error_body("INVALID_REQUEST", str(error)))
            return

        self._send(200, {
            **result,
            "contractVersion": payload["contractVersion"],
            "ruleVersion": rule_version,
            "activeCatalogVersion": self.server.catalog["version"],
        })

    def _authorized(self) -> bool:
        if self.server.demo_mode:
            return True
        scheme, _, token = self.headers.get("Authorization", "").partition(" ")
        if scheme.lower() != "bearer" or not token.strip():
            return False
        try:
            from firebase_admin import auth
            auth.verify_id_token(token.strip(), app=self.server.firebase_app)
            return True
        except Exception:
            return False

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
    app = firebase_admin.initialize_app(
        credentials.ApplicationDefault(),
        {"projectId": project_id},
    )
    db = firestore.client(app=app, database_id=database_id)
    server = AnalysisHTTPServer(
        (host, port), db=db, app=app, catalog=catalog,
        database_id=database_id, demo_mode=demo_mode,
    )
    print(f"API listening at http://{host}:{port}")
    print(f"Firestore: project={project_id}, database={database_id}, collection=products")
    print(
        f"Alias catalog version: {catalog['version']}; "
        "analysis rules are loaded from Firestore per request"
    )
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
