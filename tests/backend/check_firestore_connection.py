import os

import firebase_admin
from firebase_admin import credentials, firestore


project_id = os.environ["FIREBASE_PROJECT_ID"]
database_id = os.environ["FIRESTORE_DATABASE_ID"]

app = firebase_admin.initialize_app(
    credentials.ApplicationDefault(),
    {"projectId": project_id},
)

db = firestore.client(app=app, database_id=database_id)

# Automatically generate a unique ID for this temporary test document.
test_ref = db.collection("_connectionChecks").document()

test_data = {
    "purpose": "BE-04 connection verification",
    "is_synthetic": True,
    "message": "Hello from Aesthelity",
}

try:
    # 1. Write a synthetic record.
    test_ref.set(test_data)
    print("PASS: Test record written.")

    # 2. Retrieve it in a separate database operation.
    snapshot = test_ref.get()

    if not snapshot.exists or snapshot.to_dict() != test_data:
        raise RuntimeError("Retrieved data does not match the written data.")

    print("PASS: Test record retrieved and values match.")

finally:
    # Attempt cleanup even if the read or comparison fails.
    test_ref.delete()

# 3. Confirm the record was removed.
if test_ref.get().exists:
    raise RuntimeError("Test record still exists after deletion.")

print("PASS: Test record deleted and deletion verified.")
print(f"Project: {project_id}")
print(f"Database: {database_id}")