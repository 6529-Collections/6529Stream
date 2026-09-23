"""Closed steward/recovery JSON meaning; prospective definitions, no authority admission."""
import argparse
import copy
import json
import re
from pathlib import Path

import jsonschema
import rfc8785
from Crypto.Hash import keccak

ROOT = Path(__file__).resolve().parents[2]
ZERO = '0x' + '0' * 64
MAX_UINT = (1 << 256) - 1
RAW = '0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f'
STEWARD = 'STREAM_STEWARD_DESIGNATION_V1'
RESPONSE = 'STREAM_RECOVERY_RESPONSE_V1'
SP = 'STREAM_STEWARD_DESIGNATION_JSON_PROFILE_V1'
RP = 'STREAM_RECOVERY_RESPONSE_JSON_PROFILE_V1'
MAIL = r'mailto:[A-Za-z0-9_+\-]+(?:\.[A-Za-z0-9_+\-]+)*@[A-Za-z0-9]+(?:[A-Za-z0-9\-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9]+(?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*'


class NoticeError(ValueError):
    pass


def digest(raw):
    return '0x' + keccak.new(digest_bits=256, data=raw).hexdigest()


def canonical(value):
    return rfc8785.dumps(value)


def closed(properties):
    return {'type': 'object', 'properties': properties, 'required': list(properties), 'additionalProperties': False}


def text(limit):
    return {'type': 'string', 'minLength': 1, 'maxLength': limit, 'x-stream-max-utf8-bytes': limit}


def nonzero_hash():
    return {'type': 'string', 'pattern': '^0x[0-9a-f]{64}$', 'not': {'const': ZERO}}


def reference_schema():
    return closed({'hash': closed({'algorithm': {'type': 'integer', 'enum': [1, 2, 3, 4, 5, 6]},
                                  'canonicalizationId': nonzero_hash(),
                                  'digest': {'type': 'string', 'pattern': '^0x(?:[0-9a-f]{2}){1,128}$'}}),
                   'uri': {**text(2048), 'x-stream-content-uri': True}})


def contact_schema():
    return {'oneOf': [closed({'kind': {'const': 'https'}, 'uri': {**text(2048), 'pattern': '^https://.+$', 'x-stream-content-uri': True}}),
                      closed({'kind': {'const': 'mailto'}, 'uri': {**text(2048), 'pattern': '^' + MAIL + '$'}}),
                      closed({'account': {'type': 'string', 'pattern': '^0x[0-9a-f]{40}$', 'not': {'const': '0x' + '0'*40}},
                              'chainId': {'type': 'string', 'pattern': '^[1-9][0-9]{0,77}$', 'x-stream-maximum': str(MAX_UINT)},
                              'kind': {'const': 'eip155'}})]}


def schema(family):
    common = {'version': {'type': 'integer', 'const': 1}, 'profileHash': nonzero_hash(), 'subjectId': nonzero_hash()}
    if family == STEWARD:
        fields = {**common, 'predecessor': {'oneOf': [{'type': 'null'}, nonzero_hash()]},
                  'steward': closed({'kind': {'enum': ['institution', 'registrar_contact']}, 'name': text(512), 'identity': reference_schema()}),
                  'contactEndpoints': {'type': 'array', 'minItems': 1, 'items': contact_schema(), 'uniqueItems': True}}
    elif family == RESPONSE:
        fields = {**common, 'recoveryId': nonzero_hash(), 'recoveryManifestHash': nonzero_hash(),
                  'response': {'enum': ['acknowledged', 'objected']}, 'grounds': text(2048),
                  'evidenceReferences': {'type': 'array', 'items': reference_schema()}}
    else:
        raise NoticeError('unknown family')
    return {'$schema': 'https://json-schema.org/draft/2020-12/schema', 'title': family, **closed(fields),
            'x-stream-constraints': [
                'Complete canonical RFC8785 payload is1..8192bytes. Every declared annotation is enforced by the supported validator.',
                'Hash algorithms1keccak256/2SHA256/3BLAKE3/6ArweaveTx require32bytes;4multihash/5IPFSCID are opaque1..128bytes. No inner-codec or fixity verification.',
                'All strings validUTF8, exact lexical values, no normalization/coercion/trimming. Full regex consumption and decodedUTF8 byte bounds.',
                'Contact tuples are canonically exact and unique; no URI equivalence or mailbox case normalization. No separate array item cap; all entries fitting total bytes remain supported.',
                'Subject/profile/predecessor, actual registry state, owner/independent provenance and current recovery/notice semantics require authenticated external checks.']}


def profile(family):
    designation = family == STEWARD
    if family not in (STEWARD, RESPONSE):
        raise NoticeError('unknown family')
    return {'name': SP if designation else RP, 'version': 1, 'semanticSchema': family,
            'canonicalization': 'RFC8785_JCS', 'maxPayloadBytes': 8192,
            'meaning': ('Explicit institution or registrar-contact identity document plus notice endpoints. A later authoritative designation replaces the notice target; no write/relay/veto grant.' if designation else
                        'Exact recoveryId is the canonical scheduled action ID used by the host, never a later executed-record hash. Exact recoveryManifestHash with acknowledged/objected and authored grounds/evidence. A response informs evaluation and is never itself a veto.'),
            'authority': 'No owner/standing/speaker flag. Actual immutable owner receipt or independent attestor receipt identifies authorship; a steward relaying owner authorization is distinct from independent steward speech.',
            'references': 'All six existing HashRef algorithms and lengths:1/2/3/6 exact32bytes;4/5 opaque1..128bytes. Nonzero canonicalizationId; any digest bytes of the correct length including zero bytes. No external identity truth, inner-codec validation, retrieval or fixity event inferred.',
            'contentURI': 'Nonempty exact StreamMetadataRenderer https/ipfs/ar predicate,2048decodedUTF8bytes. No whitespace/control/DEL; HTTPS first suffix character is not slash/question/hash. No URI normalization or availability promise.',
            'endpoints': 'HTTPS uses the contentURI rule and exact scheme. MAILTO is one ASCII mailbox with dot-atom local subset letters/digits/_/+/-, and alphanumeric/hyphen host labels separated by dots; no quoted local, headers, escapes or SMTP/DNS claim. EIP155 has canonical positiveuint256 chainId decimal string and nonzero lowercase20byte account. No institution/person inference from account.',
            'arraySemantics': 'No arbitrary item-count limit. Contacts nonempty and canonical exact tuples unique; evidence explicitly present, may be empty, order and duplicates retained. Full encoded8192byte bound applies to every array.',
            'optionalData': 'All JSON fields required; designation predecessor explicitly null or nonzerohash. No inferred absence/default response. Inactive Solidity contact fields zero/empty.',
            'text': 'ValidUTF8 with no normalization/coercion/trimming; fixed ASCII keys and exact escaping. Steward name512, grounds2048, URI2048 decoded bytes plus complete encoded bound.',
            'registrationStatus': 'Prospective immutable schema/profile bytes; pure interpretation does not register documents, index notices, select current records or establish recovery scheduling/timeliness/authority.'}


def _pairs(rows):
    out = {}
    for key, value in rows:
        if key in out:
            raise NoticeError('duplicate JSON key')
        out[key] = value
    return out


def load(raw):
    if not isinstance(raw, bytes) or not 0 < len(raw) <= 8192:
        raise NoticeError('complete payload byte bound')
    def reject(_):
        raise NoticeError('inexact or nonfinite JSON number')
    try:
        value = json.loads(raw.decode('utf8'), object_pairs_hook=_pairs, parse_float=reject, parse_constant=reject)
        if canonical(value) != raw:
            raise NoticeError('noncanonical JSON')
        return value
    except (ValueError, UnicodeError, TypeError, RecursionError) as exc:
        raise NoticeError(str(exc)) from exc


def _annotations(value, s):
    if 'oneOf' in s:
        branches = [b for b in s['oneOf'] if jsonschema.Draft202012Validator(b).is_valid(value)]
        if len(branches) != 1:
            raise NoticeError('closed variant')
        _annotations(value, branches[0])
    if isinstance(value, dict):
        for key, item in value.items():
            _annotations(item, s.get('properties', {}).get(key, {}))
    elif isinstance(value, list):
        for item in value:
            _annotations(item, s.get('items', {}))
    elif isinstance(value, str):
        if 'pattern' in s and re.fullmatch(s['pattern'], value) is None:
            raise NoticeError('full lexical grammar')
        if len(value.encode('utf8')) > s.get('x-stream-max-utf8-bytes',8192):
            raise NoticeError('decodedUTF8 bound')
        if 'x-stream-maximum' in s and int(value) > int(s['x-stream-maximum']):
            raise NoticeError('unsigned overflow')
        if s.get('x-stream-content-uri'):
            if not value.startswith(('https://', 'ipfs://', 'ar://')):
                raise NoticeError('content URI scheme')
            offset = value.index('://') + 3
            if len(value) == offset or any(ord(c) <= 32 or ord(c) == 127 for c in value) or value.startswith('https://') and value[offset] in '/?#':
                raise NoticeError('content URI lexical rule')


def validate(raw, family):
    value = load(raw)
    try:
        s = schema(family)
        jsonschema.Draft202012Validator(s).validate(value)
        _annotations(value, s)
        refs = [value['steward']['identity']] if family == STEWARD else value['evidenceReferences']
        for ref in refs:
            h = ref['hash']
            size = (len(h['digest']) - 2) // 2
            if h['algorithm'] in (1, 2, 3, 6) and size != 32:
                raise NoticeError('fixed digest shape')
    except (jsonschema.ValidationError, ValueError, TypeError) as exc:
        raise NoticeError(str(exc)) from exc
    return value


def examples():
    h = lambda n: '0x' + format(n,'064x')
    ref = lambda a=2: {'hash': {'algorithm': a, 'canonicalizationId': RAW, 'digest': h(3)}, 'uri': 'ipfs://identity-document'}
    d = {'version': 1, 'subjectId': h(1), 'profileHash': digest(canonical(profile(STEWARD))), 'predecessor': None,
         'steward': {'kind': 'institution', 'name': 'Explicit institution', 'identity': ref()},
         'contactEndpoints': [{'kind': 'https', 'uri': 'https://institution.example/notice'}, {'kind': 'mailto', 'uri': 'mailto:registrar+stream@example.org'},
                              {'kind': 'eip155', 'chainId': str(MAX_UINT), 'account': '0x' + 'ab'*20}]}
    successor = copy.deepcopy(d)
    successor['predecessor'] = h(9)
    successor['steward']['kind'] = 'registrar_contact'
    successor['steward']['name'] = 'Exact " \\ /\r\n\u0001 🎨 e\u0301'
    successor['steward']['identity']['hash'].update(algorithm=5,digest='0x00ff7f')
    response = {'version': 1, 'subjectId': h(1), 'profileHash': digest(canonical(profile(RESPONSE))), 'recoveryId': h(4),
                'recoveryManifestHash': h(5), 'response': 'acknowledged', 'grounds': 'Owner or independent authored statement; carrier determines attribution.', 'evidenceReferences': []}
    objection = copy.deepcopy(response)
    objection.update(response='objected', grounds='Exact grounds " \\ /\r\n\u0001 🎨 e\u0301', evidenceReferences=[ref(a) for a in range(1,7)])
    objection['evidenceReferences'][3]['hash']['digest'] = '0x' + '00ff'*64
    objection['evidenceReferences'][4]['hash']['digest'] = '0x00'
    return {'steward-institution.json': d, 'steward-registrar.json': successor,
            'recovery-acknowledged.json': response, 'recovery-objected.json': objection}


def definitions(documents):
    out = ['// SPDX-License-Identifier: MIT', 'pragma solidity ^0.8.19;', '',
           '/// @notice Exact prospective owner-notice schema/profile documents; no registration claim.',
           'library StreamOwnerNoticeDefinitions {']
    for label, name in [('STEWARD_SCHEMA',STEWARD),('STEWARD_PROFILE',SP),('RESPONSE_SCHEMA',RESPONSE),('RESPONSE_PROFILE',RP)]:
        raw = documents[name]
        identity=f'    bytes32 internal constant {label}_ID = keccak256("{name}");'
        if len(identity)>100:
            identity=f'    bytes32 internal constant {label}_ID =\n        keccak256("{name}");'
        out += [identity,
                f'    bytes32 internal constant {label}_HASH =', f'        {digest(raw)};',
                f'    uint256 internal constant {label}_BYTES = {len(raw)};']
    out += ['}', '']
    return '\n'.join(out).encode('utf8')


def outputs():
    docs = {STEWARD: canonical(schema(STEWARD)), RESPONSE: canonical(schema(RESPONSE)),
            SP: canonical(profile(STEWARD)), RP: canonical(profile(RESPONSE))}
    out = {'schemas/records/' + n + '.json': raw for n,raw in docs.items()}
    for name, value in examples().items():
        raw = canonical(value)
        validate(raw, STEWARD if name.startswith('steward') else RESPONSE)
        out['schemas/records/examples/owner-notice/' + name] = raw
    out['smart-contracts/domains/records/StreamOwnerNoticeDefinitions.sol'] = definitions(docs)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for path, raw in outputs().items():
        target = ROOT / path
        if args.check:
            if not target.exists() or target.read_bytes() != raw:
                raise NoticeError('generated bytes differ: ' + path)
        else:
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(raw)
    print('Owner notice definitions and four complete examples match.' if args.check else 'Generated owner notice definitions and examples.')


if __name__ == '__main__':
    main()
