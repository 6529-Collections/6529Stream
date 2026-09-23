"""Closed prospective native-script interpretation documents.

These exact bytes are registration inputs, not evidence of registration. A
selected SchemaRegistry capture must replay and match all four documents
before they can interpret a token script observation.
"""
from . import collection_script_wire_v1 as wire
from . import genesis_registry_plan_v1 as genesis
from .canonical import dumps, keccak256, schema_id
from .independent_wire import ZERO
from .publication import PublicationPlan

CANON_NAME = 'STREAM_NATIVE_SCRIPT_MANIFEST_CANONICALIZATION_V1'
SCHEMA_NAME = 'STREAM_NATIVE_SCRIPT_MANIFEST_SCHEMA_V1'
CATALOG_NAME = 'STREAM_NATIVE_SCRIPT_FORMAT_CATALOG_V1'
CANON_ID = schema_id(CANON_NAME)
JCS_NAME = 'RFC8785_JCS'

CANON_BYTES = dumps({'name': CANON_NAME, 'version': '1',
    'documentEncoding': 'RFC8785_JCS',
    'nativeManifestEncoding': 'Solidity abi.encode of the exact V1 typed fields',
    'payloadEncoding': 'ordered raw bytes; Keccak-256 of the complete byte stream',
    'stableHashDomain': wire.STABLE_DOMAIN,
    'chunkedHashDomain': wire.CHUNKED_DOMAIN,
    'bundleHashDomain': wire.BUNDLE_DOMAIN,
    'wireProfileHash': wire.PROFILE_HASH})
HASH = {'type': 'string', 'pattern': '^0x[0-9a-f]{64}$'}
ADDRESS = {'type': 'string', 'pattern': '^0x[0-9a-f]{40}$'}
UINT = {'type': 'string', 'pattern': '^(0|[1-9][0-9]*)$'}
SCHEMA_BYTES = dumps({'$schema': 'https://json-schema.org/draft/2020-12/schema',
    '$id': 'urn:6529stream:schema:' + SCHEMA_NAME,
    'title': SCHEMA_NAME, 'type': 'object', 'additionalProperties': False,
    'required': ['chainId', 'core', 'collectionId', 'tokenId', 'blockHash',
        'selection', 'manifest', 'scriptPayloadHash', 'dependencyStatus'],
    'properties': {'chainId': UINT, 'core': ADDRESS, 'collectionId': UINT,
        'tokenId': UINT, 'blockHash': HASH,
        'selection': {'type': 'object', 'additionalProperties': False,
            'required': ['host', 'codeHash', 'manifestHash'],
            'properties': {'host': ADDRESS, 'codeHash': HASH, 'manifestHash': HASH}},
        'manifest': {'type': 'object', 'additionalProperties': False,
            'required': sorted(wire.MANIFEST_KEYS),
            'properties': {'scriptHash': HASH, 'rendererCompatibility':
                {'enum': [wire.STABLE_PROFILE, wire.CHUNKED_PROFILE]},
                'sourceType': UINT, 'libraryURI': {'type': 'string'},
                'scriptURI': {'type': 'string'}, 'sourcePointer': {'type': 'string'},
                'mimeType': {'const': 'application/javascript'},
                'chunkCount': UINT, 'executable': {'const': True}}},
        'scriptPayloadHash': HASH,
        'dependencyStatus': {'enum': ['authenticated_empty', 'complete']},
        'dependencyManifest': {'type': ['object', 'null'],
            'additionalProperties': False,
            'required': sorted(wire.DEPENDENCY_KEYS),
            'properties': {'dependencyId': HASH, 'dependencyHash': HASH,
                'sourceType': UINT, 'dependencyURI': {'type': 'string'},
                'sourcePointer': {'type': 'string'}, 'version': {'type': 'string'},
                'mimeType': {'type': 'string'}, 'useDependencyRegistry': {'type': 'boolean'}}}},
    'x-stream-native-manifest-abi': wire.SCRIPT_MANIFEST_ABI,
    'x-stream-native-dependency-abi': wire.DEPENDENCY_MANIFEST_ABI,
    'x-stream-wire-profile-hash': wire.PROFILE_HASH,
    'x-stream-negative-class-from-absence': False})
CATALOG_BYTES = dumps({'name': CATALOG_NAME, 'version': '1',
    'entries': [
        {'compatibility': wire.STABLE_PROFILE, 'manifestDomain': wire.STABLE_DOMAIN,
            'scriptPayload': 'complete inline UTF-8 bytes',
            'dependency': 'exact native empty for this selected occurrence'},
        {'compatibility': wire.CHUNKED_PROFILE, 'manifestDomain': wire.CHUNKED_DOMAIN,
            'scriptPayload': 'complete ordered immutable bundle bytes',
            'dependency': 'selected library bundle complete or exact native empty'}],
    'unsupported': 'unavailable calls, zero selection, incomplete bytes, other compatibility'})


def documents():
    jcs = next(row for row in genesis.prepare().documents if row.name == JCS_NAME)
    return (jcs,
        PublicationPlan(CANON_NAME, 'CANONICALIZATION', schema_id(JCS_NAME), ZERO,
            'urn:6529stream:interpretation:script-manifest-canonicalization:v1', CANON_BYTES),
        PublicationPlan(SCHEMA_NAME, 'SCHEMA', CANON_ID, ZERO,
            'urn:6529stream:interpretation:script-manifest-schema:v1', SCHEMA_BYTES),
        PublicationPlan(CATALOG_NAME, 'CATALOG', CANON_ID, ZERO,
            'urn:6529stream:interpretation:script-format-catalog:v1', CATALOG_BYTES))


PROFILE = 'STREAM_MUSEUM_TOKEN_SCRIPT_INTERPRETATION_V1'
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1',
    'documents': [{'name': row.name, 'kind': row.kind,
        'documentId': schema_id(row.name), 'contentHash': keccak256(row.content),
        'canonicalizationId': row.canonicalization_id}
        for row in documents()],
    'nativeCompatibility': [wire.STABLE_PROFILE, wire.CHUNKED_PROFILE],
    'nativeManifestDomains': [wire.STABLE_DOMAIN, wire.CHUNKED_DOMAIN],
    'wireProfileHash': wire.PROFILE_HASH,
    'qualification': 'Prospective exact document plan only; native registration must be observed separately.'})
PROFILE_HASH = keccak256(PROFILE_BYTES)
