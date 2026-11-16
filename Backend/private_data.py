"""User-scoped Admin SDK storage. All entry points require verified identity."""
from datetime import datetime, timezone
import json


class PrivateDataError(Exception):
    def __init__(self, status, code, message):
        self.status, self.code = status, code
        super().__init__(message)


def segment(value):
    if not isinstance(value, str) or not value or len(value) > 128 or value in {'.', '..'} or any(c in value for c in '/\\') or any(ord(c) < 32 for c in value):
        raise PrivateDataError(400, 'INVALID_REQUEST', 'Invalid record identifier.')
    return value


class PrivateDataStore:
    def __init__(self, db):
        self.db = db

    def collection(self, actor, owner, kind):
        if not actor:
            raise PrivateDataError(401, 'UNAUTHENTICATED', 'Sign in is required.')
        if actor != owner:
            raise PrivateDataError(403, 'FORBIDDEN', 'Access denied.')
        segment(owner)
        if kind not in {'profile', 'routines', 'analyses', 'products'}:
            raise PrivateDataError(404, 'NOT_FOUND', 'Route not found.')
        return self.db.collection('users').document(owner).collection(kind)

    def execute(self, actor, owner, kind, record_id, method, payload=None):
        collection = self.collection(actor, owner, kind)
        if kind == 'profile' and record_id != 'skinProfile':
            raise PrivateDataError(400, 'INVALID_REQUEST', 'Use profile/skinProfile.')
        if record_id is None:
            if method != 'GET':
                raise PrivateDataError(405, 'METHOD_NOT_ALLOWED', 'A record ID is required.')
            return {'records': [self.public(doc) for doc in collection.limit(100).stream()]}
        ref = collection.document(segment(record_id))
        if method == 'GET':
            doc = ref.get()
            if not doc.exists:
                raise PrivateDataError(404, 'NOT_FOUND', 'Record not found.')
            return {'record': self.public(doc)}
        if method == 'DELETE':
            ref.delete()
            return {'deleted': True, 'id': record_id}
        if method != 'PUT':
            raise PrivateDataError(405, 'METHOD_NOT_ALLOWED', 'Use GET, PUT, or DELETE.')
        if not isinstance(payload, dict) or set(payload) != {'contractVersion', 'data'} or type(payload['contractVersion']) is not int or payload['contractVersion'] != 1 or not isinstance(payload['data'], dict):
            raise PrivateDataError(400, 'INVALID_REQUEST', 'Expected contractVersion 1 and a data object only.')
        data = payload['data']
        try:
            encoded = json.dumps(data, allow_nan=False)
            if len(encoded.encode()) > 100_000:
                raise ValueError()
            self.validate(data, owner, 0)
        except (ValueError, RecursionError, TypeError):
            raise PrivateDataError(400, 'INVALID_REQUEST', 'Invalid private record data.') from None
        # Server controls identity and metadata; client content stays in data.
        record = {'ownerUID': actor, 'data': data, 'updatedAt': datetime.now(timezone.utc).isoformat()}
        ref.set(record)
        return {'record': {'id': record_id, **record}}

    def validate(self, value, owner, depth):
        if depth > 20:
            raise ValueError()
        if isinstance(value, dict):
            for key, child in value.items():
                if key.casefold() in {'uid', 'userid', 'user_id', 'owneruid', 'owner_uid'}:
                    raise ValueError()
                if key in {'product_path', 'productPath'}:
                    if not isinstance(child, str):
                        raise ValueError()
                    parts = child.split('/')
                    if len(parts) == 2 and parts[0] == 'products':
                        segment(parts[1])
                    elif len(parts) == 4 and parts[:3] == ['users', owner, 'products']:
                        segment(parts[3])
                    else:
                        raise PrivateDataError(403, 'FORBIDDEN', 'Invalid product reference.')
                self.validate(child, owner, depth + 1)
        elif isinstance(value, list):
            for child in value:
                self.validate(child, owner, depth + 1)

    @staticmethod
    def public(doc):
        return {'id': doc.id, **(doc.to_dict() or {})}
