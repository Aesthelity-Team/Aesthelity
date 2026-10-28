# AN-02 implementation review

## Review outcome

The team approved the proposed v1 ingredient-analysis rules. I reviewed the proposal for implementation feasibility and confirmed the decisions with the team.

## Approved decisions

- **Caution (moderate):** Retinol, benzoyl peroxide, or tretinoin used with an exfoliant produces a caution finding.
- **Conflict (high):** A conflict applies only when tretinoin conventional gel at 0.025% is mixed with benzoyl peroxide lotion at 10%.
- **Allergen:** An allergen finding requires an exact match to an ingredient the user recorded as an allergy.
- **Unknown data:** Missing or uncertain ingredient information remains unknown or incomplete. It is not treated as safe.
- **No finding:** Display “No recorded conflicts.” This label does not mean the routine is safe.

## AN-03 and AN-06 handoff

The analysis engine evaluates rules within the supplied AM or PM routine and preserves product order in its results. It does not recommend a product layering sequence; that recommendation belongs to AN-06.
