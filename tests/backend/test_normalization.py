"""Offline contract/failure tests. Fixtures are test-only, never alias data."""
import copy
import json
import threading
import unittest
from http.client import HTTPConnection
from unittest.mock import patch
from io import BytesIO
from analysis_engine.normalization import (
    NormalizationInputError, ProviderError, OpenAINormalizationProvider,
    normalize_ingredients, normalize_products,
)
from Backend.analysis_api import AnalysisHTTPServer


def row(i=0, status='matched', name='Aqua', proposed=None):
    return dict(index=i, status=status, canonicalName=name, proposedName=proposed, reason='Identity proposal')


class FakeProvider:
    model = 'test-only'
    def __init__(self, rows=None, error=None):
        self.rows = rows if rows is not None else [row()]
        self.error, self.calls = error, []
    def resolve(self, texts):
        self.calls.append(list(texts))
        if self.error:
            raise ProviderError(self.error)
        return {'ingredients': copy.deepcopy(self.rows)}


class NormalizationTests(unittest.TestCase):
    def test_preserves_exact_originals_duplicates_order_and_calls_each_time(self):
        provider = FakeProvider([row(), row(1)])
        for _ in range(2):
            result = normalize_ingredients([' Water ', 'Water'], provider)
            self.assertEqual([r['originalText'] for r in result['ingredients']], [' Water ', 'Water'])
            self.assertEqual([r['canonicalName'] for r in result['ingredients']], ['Aqua', 'Aqua'])
        self.assertEqual(len(provider.calls), 2)

    def test_uncertainty_and_unknown(self):
        p = FakeProvider([row(status='uncertain', name=None, proposed='Tocopherol'),
                          row(1, 'unknown', None)])
        result = normalize_ingredients(['Vitamin E', 'nonsense'], p)
        self.assertTrue(result['uncertaintyPreserved'])
        self.assertTrue(all(r['canonicalName'] is None for r in result['ingredients']))

    def test_failures_preserve_rows(self):
        for error in ['provider_unconfigured', 'provider_rate_limited', 'provider_unavailable', 'provider_incomplete_or_refused']:
            with self.subTest(error=error):
                r = normalize_ingredients(['Water'], FakeProvider(error=error))
                self.assertEqual(r['providerStatus'], error)
                self.assertEqual(r['ingredients'][0]['status'], 'unknown')

    def test_rejects_invalid_output_atomically(self):
        bad = [[], [row(1)], [row(name=None)], [row(status='safe')],
               [row(status='unknown')], [{**row(), 'unexpected': True}], [row(i=True)],
               [row(proposed='Something')], [row(name='')]]
        for rows in bad:
            with self.subTest(rows=rows):
                r = normalize_ingredients(['Water'], FakeProvider(rows))
                self.assertEqual(r['providerStatus'], 'provider_invalid_response')
                self.assertEqual(r['ingredients'][0]['canonicalName'], None)

    def test_invalid_input_never_calls_provider(self):
        p = FakeProvider()
        for texts in [None, 'Water', [123], ['x' * 501], ['Water'] * 201]:
            with self.assertRaises(NormalizationInputError):
                normalize_ingredients(texts, p)
        self.assertEqual(p.calls, [])

    def test_empty_input_cannot_be_matched(self):
        self.assertEqual(normalize_ingredients(['  '], FakeProvider())['ingredients'][0]['status'], 'unknown')
        p = FakeProvider()
        self.assertEqual(normalize_ingredients([], p)['ingredients'], [])
        self.assertEqual(p.calls, [])

    def test_products_batch_and_partial_coverage(self):
        p = FakeProvider([row(), row(1)])
        result = normalize_products([
            dict(productID='catalog', listStatus='complete', ingredients=['Water']),
            dict(productID='manual', listStatus='partial', ingredients=['Aqua'])], p)
        self.assertEqual(p.calls, [['Water', 'Aqua']])
        self.assertEqual([v['productID'] for v in result['products']], ['catalog', 'manual'])
        self.assertEqual(result['products'][1]['ingredients'][0]['index'], 0)
        self.assertTrue(result['uncertaintyPreserved'])

    def test_missing_lists_and_duplicate_products(self):
        for products in [[], [dict(productID='x', listStatus='complete', ingredients=[])],
                         [dict(productID='x', listStatus='unavailable', ingredients=[])]]:
            if not products:
                with self.assertRaises(NormalizationInputError): normalize_products(products, FakeProvider())
            else:
                self.assertTrue(normalize_products(products, FakeProvider())['uncertaintyPreserved'])
        p = dict(productID='x', listStatus='complete', ingredients=[])
        with self.assertRaises(NormalizationInputError): normalize_products([p, p], FakeProvider())

    @patch('analysis_engine.normalization.urlopen')
    def test_real_provider_wire_contract_and_refusal(self, call):
        envelope = {'choices': [{'finish_reason': 'stop', 'message': {'content': json.dumps({'ingredients': [row()]})}}]}
        call.return_value.__enter__.return_value = BytesIO(json.dumps(envelope).encode())
        p = OpenAINormalizationProvider(api_key='test-key', model='test-model')
        self.assertEqual(normalize_ingredients(['Water'], p)['providerStatus'], 'ok')
        body = json.loads(call.call_args.args[0].data)
        self.assertTrue(body['response_format']['json_schema']['strict'])
        self.assertFalse(body['store'])
        self.assertEqual(call.call_args.kwargs['timeout'], 30)
        envelope['choices'][0]['message']['refusal'] = 'refused'
        call.return_value.__enter__.return_value = BytesIO(json.dumps(envelope).encode())
        self.assertEqual(normalize_ingredients(['Water'], p)['ingredients'][0]['status'], 'unknown')

    def test_http_endpoint_auth_validation_and_success(self):
        provider = FakeProvider()
        server = AnalysisHTTPServer(('127.0.0.1', 0), db=None, app=None,
            catalog={'version': 3}, database_id='test', demo_mode=True, normalization_provider=provider)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            def post(body):
                conn = HTTPConnection(*server.server_address)
                conn.request('POST', '/api/v1/ingredient-normalizations', json.dumps(body), {'Content-Type': 'application/json'})
                response = conn.getresponse()
                status, data = response.status, json.loads(response.read())
                conn.close()
                return status, data
            body = dict(contractVersion=1, products=[dict(productID='manual', listStatus='complete', ingredients=['Water'])])
            status, data = post(body)
            self.assertEqual(status, 200)
            self.assertEqual(data['products'][0]['ingredients'][0]['canonicalName'], 'Aqua')
            self.assertEqual(post(dict(contractVersion=1, products='bad'))[0], 400)
            server.demo_mode = False
            self.assertEqual(post(body)[0], 401)
            self.assertEqual(len(provider.calls), 1)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

if __name__ == '__main__': unittest.main()
