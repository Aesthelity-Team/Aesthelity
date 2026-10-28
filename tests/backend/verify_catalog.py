import os

import firebase_admin
from firebase_admin import credentials, firestore

from demo_catalog import load, validate


def main():
    catalog = validate(load())
    expected = {product["id"]: product for product in catalog["products"]}

    app = firebase_admin.initialize_app(
        credentials.ApplicationDefault(),
        {"projectId": os.environ["FIREBASE_PROJECT_ID"]},
    )

    db = firestore.client(
        app=app,
        database_id=os.environ["FIRESTORE_DATABASE_ID"],
    )

    # Check 1: Retrieve a known product by ID.
    product_id = "cleanser_gel"
    snapshot = db.collection("products").document(product_id).get()

    if not snapshot.exists:
        raise RuntimeError(f"Product {product_id!r} was not found.")

    if snapshot.to_dict() != expected[product_id]:
        raise RuntimeError(
            f"Stored product {product_id!r} does not match the dataset."
        )

    print(f"PASS: Retrieved {product_id}; all fields match.")

    # Check 2: List the catalog.
    stored = {
        document.id: document.to_dict()
        for document in db.collection("products").stream()
    }

    missing = set(expected) - set(stored)
    unexpected = set(stored) - set(expected)

    if missing:
        raise RuntimeError(f"Missing product IDs: {sorted(missing)}")

    if unexpected:
        raise RuntimeError(
            f"Unexpected product IDs: {sorted(unexpected)}"
        )

    # Check 3: Compare every stored product with its source record.
    for product_id, product in expected.items():
        if stored[product_id] != product:
            raise RuntimeError(
                f"Stored product {product_id!r} does not match the dataset."
            )

    print(f"PASS: Listed {len(stored)} products.")
    print("PASS: All product IDs and fields match the source dataset.")

    for product_id in sorted(stored):
        print(f"  {product_id}: {stored[product_id]['name']}")


if __name__ == "__main__":
    main()