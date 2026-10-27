import os
import argparse

import firebase_admin
from firebase_admin import credentials, firestore

from demo_catalog import load, validate


def main():
    # Validate the existing demo dataset before connecting or writing.
    try:
        catalog = validate(load())
        products = catalog["products"]

        for index, product in enumerate(products):
            product_id = product["id"]

            # Firestore document IDs must be usable as one path segment.
            if (
                "/" in product_id
                or product_id in {".", ".."}
                or len(product_id.encode("utf-8")) > 1500
            ):
                raise ValueError(
                    f"Product at index {index}: "
                    f"invalid Firestore document ID {product_id!r}"
                )

    except (ValueError, KeyError, TypeError, OSError) as error:
        raise SystemExit(
            f"Validation failed: {error}\n"
            "Import stopped. No products were written."
        ) from error

    print(f"PASS: Validated {len(products)} products.")

    project_id = os.environ["FIREBASE_PROJECT_ID"]
    database_id = os.environ["FIRESTORE_DATABASE_ID"]

    app = firebase_admin.initialize_app(
        credentials.ApplicationDefault(),
        {"projectId": project_id},
    )

    db = firestore.client(app=app, database_id=database_id)

    print(f"Target project: {project_id}")
    print(f"Target database: {database_id}")

    # Save each complete product under its existing stable ID.
    for product in products:
        product_id = product["id"]
        db.collection("products").document(product_id).set(product)
        print(f"Saved: products/{product_id}")

    print(f"PASS: Imported {len(products)} products.")


if __name__ == "__main__":
    main()