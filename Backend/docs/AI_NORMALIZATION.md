# #98: AI ingredient normalization and alias resolution

## Design

The professor's generative-AI direction supersedes #98's original database-alias
plan. `analysis_engine/normalization.py` resolves ingredient identities through
OpenAI Structured Outputs on every nonempty request. No alias database, bundled
alias lookup, fuzzy spelling table, or persisted normalization cache is used by
this flow. The only fixed rules here validate data shape and uncertainty; they
are not ingredient mappings or skincare interaction rules.

`matched` means the model proposes one unambiguous identity. It does **not** mean
safe, independently verified, or eligible for the old catalog-based rules.
`uncertain` retains a possible proposed name without assigning a canonical name.
`unknown` has neither name. No model-created canonical IDs enter the old engine.

The backend copies original text from the request and retains duplicates, order,
product IDs, and list coverage. Invalid or incomplete provider output invalidates
the entire batch and returns unknown rows. Configuration, network, timeout,
refusal, and rate-limit failures also preserve unknown rows with provider status.
The endpoint returns HTTP 200 for these explicit degraded results; callers must
inspect `providerStatus` and `uncertaintyPreserved`. Invalid requests return 400;
unauthenticated requests return 401 outside loopback demo mode.

## Local setup

Use the existing Firebase setup in `Backend/README.md`. Set these environment
variables **on the backend only**, in the same terminal used to start it:

```sh
read -rsp 'OpenAI API key: ' OPENAI_API_KEY; echo
export OPENAI_API_KEY
export AESTHELITY_NORMALIZATION_MODEL='YOUR_STRUCTURED_OUTPUT_CAPABLE_MODEL_ID'
AESTHELITY_DEMO_MODE=1 python Backend/analysis_api.py
```

Choose an available model supporting strict JSON schema Chat Completions. There
is deliberately no hard-coded model selection. Missing configuration returns
`provider_unconfigured`; it never falls back to aliases or a fabricated match.
No extra Python dependencies are required beyond the existing Firebase backend.
The provider uses HTTPS, a 30-second timeout, and no automatic retries. Credentials
and provider response bodies are not logged or returned. Raw ingredient strings
are sent to OpenAI; no profile, user ID, or allergy data is sent by this service.

## Request and response

```sh
curl -s http://127.0.0.1:8765/api/v1/ingredient-normalizations \
  -H 'Content-Type: application/json' \
  -d '{"contractVersion":1,"products":[{"productID":"manual-1","listStatus":"partial","ingredients":["Water","Vitamin E","unrecognized label text"]}]}'
```

Outside demo mode also send `Authorization: Bearer <Firebase-ID-token>`.
Both catalog and manually entered products use this identical request shape.
Send separate ingredient strings, not an unsplit label. Maximum 50 products,
200 total rows, and 500 characters per ingredient. Product IDs must be unique.
Unavailable lists must be empty; empty complete lists retain a coverage gap.

The result contains `contractVersion`, `normalizationID`, `promptVersion`,
`model`, `providerStatus`, `uncertaintyPreserved`, and `products`. Each product
retains `productID`, `listStatus`, and its `ingredients`. Each ingredient has
`index`, exact `originalText`, `status` (`matched`, `uncertain`, `unknown`),
nullable `canonicalName`, nullable `proposedName`, and `reason`.
Model output is a proposal and may vary between requests. A structurally valid
response does not establish factual accuracy; representative live evaluation is
required before marking acceptance complete.

## iOS and #99 handoff

`BackendAnalysisAPI.normalize(products:idToken:)` is the Swift client entry point
for both product sources. Its response retains displayable raw and resolved names.
The existing Analysis demo still uses the legacy Swift normalizer and fixed-rule
engine. It is **not** evidence that the AI analysis migration is complete.

For #99, call `normalize_products(raw_products, provider)` once on the backend,
then pass that validated in-memory response directly into the generative-AI
analysis engine. Preserve product/row links, list coverage and unresolved rows.
Do not normalize again in Swift or in #99, invent catalog membership, convert
unknown to safe, or accept client claims of a verified match. Do not submit the
new response to `evaluate_routine`, which expects legacy catalog IDs. The
normalization ID is traceability metadata, not a trusted server-side lookup token.
#99 owns AI analysis findings, explanations, and replacement of fixed interaction
rules. It should reject or return explicit unknown analysis when normalization
fails. The combined backend analysis route should return traceable normalization
alongside findings so details can display both original and resolved names.

## Validation and remaining completion work

```sh
python -m unittest discover -s tests -v
```

27 tests passed locally, including 10 normalization tests covering request-scoped
calls, duplicates, ambiguity, unsupported text, malformed output, coverage,
provider refusal, sanitized failure states, real-provider request serialization,
and HTTP authentication/validation. Provider calls in tests are mocked.

Still required: configure a real key/model; run and review live alias, typo,
family/mixture, unsupported-text and prompt-injection samples; build/test the iOS
client in Xcode; wire the product details UI and #99 AI analysis path; obtain PR
review. Live model accuracy and iOS compilation were not verified here. The
issue remains open pending this evidence and integration.

Reference: https://developers.openai.com/api/docs/guides/structured-outputs
