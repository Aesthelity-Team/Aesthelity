import copy
import unittest
from scripts.demo_catalog import load, validate, evaluate
class CatalogTests(unittest.TestCase):
    def setUp(self): self.c=load()
    def test_dataset(self): validate(self.c)
    def test_duplicate_id_rejected(self):
        self.c['products'].append(copy.deepcopy(self.c['products'][0]))
        with self.assertRaises(ValueError): validate(self.c)
    def test_broken_reference_rejected(self):
        self.c['scenarios'][0]['product_ids']=['missing']
        with self.assertRaises(ValueError): validate(self.c)
    def test_missing_scenario_rejected(self):
        self.c['scenarios']=[s for s in self.c['scenarios'] if s['scenario_type']!='allergen']
        with self.assertRaises(ValueError): validate(self.c)
    def test_invented_spf_rejected(self):
        self.c['products'][0]['spf']=30
        with self.assertRaises(ValueError): validate(self.c)
    def test_allergy_depends_on_profile_and_normalizes_case(self):
        p=next(p for p in self.c['products'] if p['id']=='mist_fragranced')
        self.assertEqual(evaluate([p],{'recorded_allergens':[]}),[])
        self.assertEqual(evaluate([p],{'recorded_allergens':[' limonene ' ]})[0]['kind'],'allergen')
    def test_partial_does_not_hide_known_allergen(self):
        p=copy.deepcopy(self.c['products'][0]); p['ingredient_list_status']='partial'
        p['ingredients']=['Limonene']
        self.assertEqual({f['kind'] for f in evaluate([p],{'recorded_allergens':['Limonene']})},{'unknown','allergen'})
    def test_retinol_alone_has_no_combination_caution(self):
        p=next(p for p in self.c['products'] if p['subtype']=='retinol')
        self.assertEqual(evaluate([p],{'recorded_allergens':[]}),[])
    def test_findings_have_user_facing_text(self):
        for s in self.c['scenarios']:
            for f in s['expected_findings']:
                for key in ('category','explanation','reason'):
                    self.assertTrue(isinstance(f[key],str) and f[key].strip(),f'{s["id"]}: missing {key}')
    def test_wrong_expected_finding_rejected(self):
        self.c['scenarios'][1]['expected_findings']=[]
        with self.assertRaises(ValueError): validate(self.c)
    def test_unavailable_cannot_have_ingredients(self):
        p=next(p for p in self.c['products'] if p['ingredient_list_status']=='unavailable')
        p['ingredients']=['Water']
        with self.assertRaises(ValueError): validate(self.c)
    def test_provenance_matches_authored_lists(self):
        from scripts.demo_catalog import ROOT
        text=(ROOT/'docs/PROVENANCE.md').read_text()
        for p in self.c['products']:
            section=text.split('## '+p['id']+'\n')[1].split('\n## ')[0]
            self.assertIn(' → '.join(p['ingredients']) or '(unavailable)',section)
if __name__=='__main__': unittest.main()
