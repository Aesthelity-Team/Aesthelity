# Aesthelity analysis engine (AN-03)

This package evaluates one AM or PM skincare routine against the team-approved
AN-02 v1 rules. It returns structured findings; it does not provide a safety
guarantee or diagnose an allergy. Severity is a display priority, not a
clinical grade. An empty result is labelled **No recorded conflicts**.

## Run the demo

From the directory containing `analysis_engine/`:

```sh
python3 -m analysis_engine.demo
```

The default case prints a moderate retinol plus glycolic acid caution. To show
other result shapes:

```sh
python3 -m analysis_engine.demo --case unknown
python3 -m analysis_engine.demo --case conflict
python3 -m analysis_engine.demo --case no-findings
```

The demo uses a small, local catalog for illustration. The conflict case adds
Tretinoin to that demo catalog because the app's version 2 catalog does not
contain it. This does not update or claim to update the production catalog.

## API

```python
from analysis_engine import evaluate_routine

result = evaluate_routine(routine, active_catalog)
```

`routine` needs `period` (`am` or `pm`), `recordedAllergies`, and a non-empty
`products` list. Product ingredient rows can use the current `mapping` shape or
the legacy `status` shape. Only confirmed ingredient IDs present in the active
catalog and backed by the current product catalog version can match rules.
Uncertain, ambiguous, unmatched, stale, and missing data produces `unknown`
coverage findings instead of being treated as safe. Invalid inputs raise
`AnalysisInputError`, with a stable `.code` for caller handling.

The evaluator preserves product order in its result and uses the same AM/PM
routine boundary when matching. It does not infer a recommended product
application sequence; AN-06 owns that recommendation. Order is not a match
condition for the approved v1 ingredient rules.

## Verify

```sh
python3 -m unittest discover -s tests -v
```
