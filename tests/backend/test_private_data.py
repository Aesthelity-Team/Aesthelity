"""HTTP acceptance tests using isolated in-memory storage and a fake verifier."""
import copy
import http.client
import json
import sys
import threading
import types
import unittest
from Backend.analysis_api import AnalysisHTTPServer


class Document:
    def __init__(self, db, path): self.db, self.path, self.id = db, path, path[-1]
    def collection(self, name): return Collection(self.db, self.path + (name,))
    def get(self): return Snapshot(self.id, self.db.rows.get(self.path))
    def set(self, value): self.db.rows[self.path] = copy.deepcopy(value)
    def delete(self): self.db.rows.pop(self.path, None)


class Snapshot:
    def __init__(self, id, value): self.id, self.value, self.exists = id, value, value is not None
    def to_dict(self): return copy.deepcopy(self.value)


class Collection:
    def __init__(self, db, path): self.db, self.path = db, path
    def document(self, name): return Document(self.db, self.path + (name,))
    def limit(self, count): return self
    def stream(self):
        return [Snapshot(p[-1], v) for p, v in self.db.rows.items() if p[:-1] == self.path]


class Database:
    def __init__(self): self.rows = {}
    def collection(self, name): return Collection(self, (name,))


class IsolationHTTPTests(unittest.TestCase):
    def setUp(self):
        self.db = Database()
        self.server = AnalysisHTTPServer(('127.0.0.1', 0), db=self.db, app=None, catalog={'version': 1}, database_id='test', demo_mode=True)
        def verify(token):
            if token not in {'alice', 'bob'}: raise ValueError('expired/invalid/revoked')
            return {'uid': token}
        self.server.token_verifier = verify
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join()

    def request(self, method, owner='alice', kind='routines', id='r1', token='alice', data=None):
        conn = http.client.HTTPConnection(*self.server.server_address, timeout=3)
        headers = {'Content-Type': 'application/json'}
        if token is not None: headers['Authorization'] = 'Bearer ' + token
        body = json.dumps(data) if data is not None else None
        path = f'/api/v1/users/{owner}/{kind}' + (f'/{id}' if id is not None else '')
        conn.request(method, path, body, headers)
        response = conn.getresponse(); result = json.loads(response.read())
        self.assertEqual(response.getheader('Cache-Control'), 'no-store')
        conn.close(); return response.status, result

    def test_own_crud_all_private_types(self):
        for kind in ['profile', 'routines', 'analyses', 'products']:
            id = 'skinProfile' if kind == 'profile' else 'record'
            for value in [1, 2]:
                status, result = self.request('PUT', kind=kind, id=id, data={'contractVersion': 1, 'data': {'value': value}})
                self.assertEqual(status, 200); self.assertEqual(result['record']['ownerUID'], 'alice')
                status, result = self.request('GET', kind=kind, id=id)
                self.assertEqual(result['record']['data']['value'], value)
            self.assertEqual(self.request('DELETE', kind=kind, id=id)[0], 200)
            self.assertEqual(self.request('GET', kind=kind, id=id)[0], 404)

    def test_cross_user_all_operations_denied_and_unchanged(self):
        for kind in ['profile', 'routines', 'analyses', 'products']:
            id = 'skinProfile' if kind == 'profile' else 'r1'
            payload = {'contractVersion': 1, 'data': {'secret': 'private'}}
            self.request('PUT', kind=kind, id=id, data=payload)
            before = copy.deepcopy(self.db.rows)
            for method in ['GET', 'PUT', 'DELETE']:
                status, body = self.request(method, kind=kind, id=id, token='bob', data=payload)
                self.assertEqual(status, 403); self.assertNotIn('secret', json.dumps(body))
                self.assertEqual(self.db.rows, before)
            self.assertEqual(self.request('GET', kind=kind, id=None, token='bob')[0], 403)

    def test_unauthenticated_and_invalid_tokens_cannot_use_demo_bypass(self):
        for token in [None, '', 'expired', 'revoked', 'forged']:
            for method in ['GET', 'PUT', 'DELETE']:
                self.assertEqual(self.request(method, token=token)[0], 401)
        self.assertEqual(self.db.rows, {})

    def test_list_is_scoped_and_same_id_is_independent(self):
        for owner in ['alice', 'bob']:
            self.request('PUT', owner=owner, token=owner, data={'contractVersion': 1, 'data': {'name': owner}})
        status, body = self.request('GET', id=None)
        self.assertEqual(status, 200); self.assertEqual(len(body['records']), 1)
        self.assertEqual(body['records'][0]['data']['name'], 'alice')

    def test_owner_spoofing_and_foreign_references_rejected(self):
        for data, expected in [({'uid': 'bob'}, 400), ({'steps': [{'product_path': 'users/bob/products/p1'}]}, 403), ({'steps': [{'product_path': 'products/p1'}]}, 200), ({'steps': [{'product_path': 'users/alice/products/p1'}]}, 200)]:
            self.assertEqual(self.request('PUT', data={'contractVersion': 1, 'data': data})[0], expected)
        self.assertEqual(self.request('PUT', data={'contractVersion': 1, 'data': {}, 'uid': 'bob'})[0], 400)

    def test_bad_paths_methods_and_database_failure(self):
        self.assertEqual(self.request('GET', id='..')[0], 400)
        self.assertEqual(self.request('POST')[0], 405)
        self.assertEqual(self.request('PUT', data={'contractVersion': True, 'data': {}})[0], 400)
        def fail(_): raise RuntimeError('private infrastructure secret')
        self.db.collection = fail
        status, body = self.request('GET')
        self.assertEqual(status, 503); self.assertNotIn('infrastructure secret', json.dumps(body))


if __name__ == '__main__': unittest.main()
