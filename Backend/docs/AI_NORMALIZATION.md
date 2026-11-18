# #98 ingredient matching (AI-primary)

Canonical documentation: **`Backend/README.md` → Ingredient resolution (#98)**.

## Prompt and schema

Versioned in `Backend/prompts/ingredient_matching_v2.py`:

- `PROMPT_VERSION`: `ingredient-matching-v2`
- Model statuses: `identified` | `tentative` | `unknown`
- Fields: `index`, `status`, `normalizedName`, `bestGuess`, `explanation`

The backend validates every index, grounds names against the approved + CosIng
catalogs, and never lets AI-stated uncertainty become `confirmed`.

## Transport

`Backend/ai_normalization.py` talks to OpenRouter (OpenAI-compatible API).
Set `OPENROUTER_API_KEY` in gitignored `Backend/.env`. Optional model overrides:
`AESTHELITY_NORMALIZATION_MODEL`, `AESTHELITY_NORMALIZATION_FALLBACK_MODEL`.
Never log or commit key values.

## Persistence and #99

- Persist: `Backend/ingredient_persistence.py` → `productIngredients` + masters
- #99 adapter: `Backend/analysis_engine_input.py` (`bestGuess` → `proposedName`)

Unit tests use a fake provider and `FakeFirestore`. Live smoke:
`AESTHELITY_LIVE_AI_TEST=1`.
