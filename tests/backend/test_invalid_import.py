import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Aesthelity/Aesthelity/Resources/DemoData"
IMPORTER = ROOT / "scripts/test_invalid_catalog.py"


def check_invalid_import(case_name, change_product):
    with tempfile.TemporaryDirectory() as temporary_directory:
        test_directory = Path(temporary_directory)

        # Copy all three dataset files into a temporary folder.
        for filename in ("products.json", "profiles.json", "scenarios.json"):
            content = (SOURCE / filename).read_text(encoding="utf-8")
            (test_directory / filename).write_text(content, encoding="utf-8")

        product_file = test_directory / "products.json"
        data = json.loads(product_file.read_text(encoding="utf-8"))

        # Deliberately damage one product in the temporary copy.
        change_product(data["products"][0])
        product_file.write_text(json.dumps(data), encoding="utf-8")

        result = subprocess.run(
            [
                sys.executable,
                str(IMPORTER),
                "--data-dir",
                str(test_directory),
            ],
            capture_output=True,
            text=True,
        )

        output = result.stdout + result.stderr

        if (
            result.returncode == 0
            or "Validation failed:" not in output
            or "No products were written." not in output
            or "Saved:" in output
        ):
            raise RuntimeError(
                f"{case_name}: importer did not reject the data as expected.\n"
                f"{output}"
            )

        print(f"PASS: {case_name}")
        print(output.strip())


check_invalid_import(
    "Missing required name",
    lambda product: product.pop("name"),
)

check_invalid_import(
    "Invalid category",
    lambda product: product.update(category="invalid_category"),
)