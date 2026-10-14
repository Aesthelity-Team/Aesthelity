"""Dependency-free loader, validation, and deliberately limited demo evaluator."""
import json
from datetime import date
from pathlib import Path
from urllib.parse import urlparse
ROOT = Path(__file__).resolve().parents[1]
CATEGORIES = {'cleanser','serum','treatment','moisturizer','sunscreen','toner','mist','mask'}
def load(directory=None):
    directory = Path(directory) if directory else ROOT / 'Aesthelity/Aesthelity/Resources/DemoData'
    result = {}
    for name in ('products','profiles','scenarios'):
        data = json.loads((directory / (name+'.json')).read_text(encoding='utf-8'))
        if data['schema_version'] != 1: raise ValueError('Unsupported schema version')
        result[name] = data[name]
    return result

def evaluate(products, profile):
    """Synthetic demo rules only. Not a skincare recommendation engine."""
    findings=[]
    allergens={x.strip().casefold() for x in profile['recorded_allergens']}
    for p in products:
        status=p['ingredient_list_status']
        if status != 'complete':
            findings.append(dict(kind='unknown',product_ids=[p['id']],ingredient=None,message=f'Ingredient list is {status}; demo assessment is incomplete.',
                category='Incomplete product data',
                explanation=f"We don't have the full ingredient list for {p['name']}, so we can't fully check it against your routine. Treat this as incomplete, not as a safe result.",
                reason=f'The ingredient list is {status}.'))
        for ingredient in p['ingredients']:
            if ingredient.strip().casefold() in allergens:
                findings.append(dict(kind='allergen',product_ids=[p['id']],ingredient=ingredient,message=f'Listed ingredient matches the demo profile’s recorded allergen: {ingredient}.',
                    category='Allergen',
                    explanation=f"{p['name']} contains {ingredient}, which you've listed as an allergen. You may want to skip this product.",
                    reason=f'{ingredient} is on your recorded allergen list.'))
    retinols=[p for p in products if p['subtype']=='retinol']
    exfoliants=[p for p in products if p['subtype'] in {'exfoliant','exfoliating'}]
    for a in retinols:
        for b in exfoliants:
            findings.append(dict(kind='caution',product_ids=[a['id'],b['id']],ingredient=None,message='Demo rule: retinol and exfoliating treatment selected together. Review this combination.',
                category='Active ingredient overlap',
                explanation='Using retinol and an exfoliating treatment in the same routine can leave skin red, dry, or irritated. Try using them on different nights.',
                reason=f"{a['name']} and {b['name']} are both in this routine."))
    return findings

def validate(catalog):
    def require(ok, message):
        if not ok: raise ValueError(message)
    for name in ('products','profiles','scenarios'):
        rows=catalog[name]
        require(isinstance(rows,list) and bool(rows),f'{name}: expected nonempty array')
        ids=[x['id'] for x in rows]
        require(all(isinstance(x,str) and x.strip() for x in ids) and len(ids)==len(set(ids)),f'{name}: invalid or duplicate IDs')
    products={p['id']:p for p in catalog['products']}
    profiles={p['id']:p for p in catalog['profiles']}
    for p in products.values():
        for key in ('name','brand','subtype','source_ref','verified_on'):
            require(isinstance(p[key],str) and bool(p[key].strip()),f'{p["id"]}: invalid {key}')
        require(p['category'] in CATEGORIES,'Invalid category')
        require(p['ingredient_list_status'] in {'complete','partial','unavailable'},'Invalid ingredient status')
        require(isinstance(p['ingredients'],list) and all(isinstance(i,str) and i.strip() for i in p['ingredients']),'Invalid ingredients')
        require((not p['ingredients']) == (p['ingredient_list_status']=='unavailable'),'Ingredient status contradicts list')
        require(p['is_fictional'] is True and 'Fictional' in p['name'],'Fictional labeling missing')
        require(p['spf'] is None,'Unverified SPF claim')
        u=urlparse(p['source_url']); require(u.scheme=='https' and bool(u.netloc),'Invalid source URL')
        require(date.fromisoformat(p['verified_on']) <= date.today(),'Verification date is in future')
        require(p['source_ref']=='docs/PROVENANCE.md#'+p['id'],'Invalid source reference')
        for key in ('kind','verification_method','note'):
            require(isinstance(p['provenance'][key],str) and bool(p['provenance'][key]),'Missing provenance')
        require(p['provenance']['kind']=='team_authored_fixture','Invalid provenance kind')
    require(CATEGORIES <= {p['category'] for p in products.values()},'Missing category coverage')
    require({'retinol','vitamin_c'} <= {p['subtype'] for p in products.values()},'Missing serum subtype coverage')
    for profile in profiles.values():
        require(isinstance(profile['recorded_allergens'],list) and all(isinstance(x,str) and x.strip() for x in profile['recorded_allergens']),'Invalid recorded allergens')
    require({s['scenario_type'] for s in catalog['scenarios']} == {'normal','caution','allergen','unknown'},'Missing scenario coverage')
    for s in catalog['scenarios']:
        require(s['routine_time'] in {'am','pm'},'Invalid routine time')
        require(isinstance(s['product_ids'],list) and bool(s['product_ids']) and len(s['product_ids'])==len(set(s['product_ids'])),'Invalid scenario products')
        require(all(i in products for i in s['product_ids']) and s['profile_id'] in profiles,'Broken scenario reference')
        actual=evaluate([products[i] for i in s['product_ids']],profiles[s['profile_id']])
        require(actual==s['expected_findings'],f'{s["id"]}: unexpected findings')
        require((not actual) if s['scenario_type']=='normal' else any(f['kind']==s['scenario_type'] for f in actual),'Scenario does not exercise its stated condition')
    return catalog

if __name__=='__main__':
    c=validate(load())
    print(f'PASS: {len(c["products"])} products, {len(c["profiles"])} profiles, {len(c["scenarios"])} scenarios')
