# AI feedback layer

The analysis engine remains the authority for matched rules, finding outcomes,
severity, and affected product/ingredient IDs. `add_ai_feedback` accepts that
structured result and asks a configured model only to write a concise summary
and clearer wording for each existing finding. Its output cannot add a finding
or change any engine field.

## Use

```python
from analysis_engine import evaluate_routine
from analysis_engine.ai_feedback import OpenAIFeedbackProvider, add_ai_feedback

result = evaluate_routine(routine, active_catalog)
response = add_ai_feedback(
    result,
    active_catalog,
    OpenAIFeedbackProvider.from_environment(),
)
```

The returned object preserves the original `findings` and adds `aiFeedback`:

- `status`: `generated`, `ai_unconfigured`, `ai_unavailable`, or another
  sanitized provider failure code.
- `generated`: whether validated AI wording was returned.
- `summary`: AI text or a deterministic fallback.
- `findingExplanations`: explanation text keyed by zero-based finding index.
- `promptVersion` and `model`: traceability fields.

When AI is unconfigured, unavailable, refuses, or returns invalid structured
output, the helper retains the deterministic findings and uses the original
engine explanations. A no-finding fallback says “No recorded rule matched” and
does not label the routine safe.

## Local configuration

The integration layer should configure these variables on the backend only:

```sh
export OPENAI_API_KEY='your-key'
export AESTHELITY_ANALYSIS_MODEL='model-id-enabled-for-your-project'
```

Never put the key in iOS code or a committed file. The provider sends structured
finding data, ingredient IDs/names, and the approved engine explanation/reason.
It does not send raw label rows, user IDs, or the full recorded-allergy list. An
allergen finding still includes its matched ingredient ID.

This helper does not read Firestore, load approved rules, or call the backend
API. The integration layer supplies the evaluator's structured result and
catalog. AI wording is advisory presentation text; it is not independently
verified evidence or a medical recommendation.
