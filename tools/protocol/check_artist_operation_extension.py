#!/usr/bin/env python3
"""Verify the additive artist operation design without relabeling implementation evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

from Crypto.Hash import keccak

from tools.protocol.check_artist_semantic_owner_matrix import MatrixError, load_strict_json

MANIFEST = Path('docs/architecture/artist-operation-extension-v1.json')
BASE = Path('release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json')
DESIGN_SHA256 = 'd54aba9ce09d939a5055904f8daf5fca554258e047259a1747901dd81e9237df'
HISTORICAL = {
    BASE.as_posix(): '34e768291af8fd0327cbd6d99177d4a829fa8d8076fdc18da58bf74912efa8df',
    'docs/architecture/artist-semantic-owner-matrix-v2.json': 'f76fc366a0a62e8c79ea064f2a1efc2f932ce6f3be86b8917ee7828dcb8ddf90',
    'docs/architecture/artist-semantic-owner-matrix-v2.schema.json': 'b242c5480ecdf8e4aa57dc02d76fd8cd81631298eeda0b96cbba9b036d72b473',
    'docs/architecture/artist-operation-shared-mechanics-freeze-v1.json': '1e8da06698d400ec4e526507551fc163513721d57ca3233c83a92c70130e41da',
    'docs/architecture/artist-operation-shared-mechanics-freeze-v1.schema.json': 'd61b29f63c662494047fc1b30bf72035ab7d586a23fe45c2bb6f2d8a0ae795b0',
    'docs/architecture/artist-owner-state-mechanics-foundation-v1.json': '2b4841ab5544c78bc64c5dea088d104b248bc2e0c3fc34fb13573ace80987e5a',
    'docs/architecture/artist-owner-state-mechanics-foundation-v1.schema.json': '2c643f5a8fe67380481f64e107878a638866627ff86ba2ea6a20086577519550',
    'docs/architecture/artist-owner-record-continuity-v1.json': '09f5d194a6d1938f8a09dfee5d34dd5b0ee5f595132216bd001097a230e53b42',
    'docs/architecture/artist-owner-record-continuity-v1.schema.json': '2c665c57e677e266eb139ad3fb9aeaa63b83f0e3204ed59d10d964052f7dfac5',
    'docs/architecture/artist-record-event-reconstruction-correction-v1.json': 'cbd235ecd06edf49f84a67d3130fa47fe99fcbab3d66431ba6edf2014dcdef7b',
    'docs/architecture/artist-record-event-reconstruction-correction-v1.schema.json': '1527009ad4ae3bf27bd7d78edf96beae44a7b27672990b4bd907dc5c1f2618f6',
}
REQUEST = [('artistId','bytes32'), ('expectedCauseHash','bytes32'), ('expectedResolutionHash','bytes32'),
           ('evidenceHash','bytes32'), ('reasonHash','bytes32'), ('removePriorStanding','bool'), ('expectedRetirementHash','bytes32')]
STOPS = ['DISMISSAL_SOURCE_AND_CONSUMERS_PENDING', 'CURRENT_EXECUTOR_SAFE_COMPOSITION_PENDING',
         'EFFECTIVE_SOURCE_CONFIGURATION_BINDING_PENDING']


class ExtensionError(ValueError):
    """The effective design or its immutable historical prefix is inconsistent."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ExtensionError(message)


def hash_text(value: str) -> str:
    return '0x' + keccak.new(digest_bits=256, data=value.encode('utf-8')).hexdigest()


def canonical_digest(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')).hexdigest()


def validate(root: Path, manifest: dict[str, Any]) -> list[list[Any]]:
    """Return the exact ordered effective rows; never mutate a historical packet."""
    require(manifest['schema'] == '6529stream.artist-operation-extension.v1', 'extension schema changed')
    require(manifest['status'] == 'ACCEPTED_DESIGN_IMPLEMENTATION_PENDING', 'design cannot claim implementation')
    expected = [{'path': path, 'sha256': digest} for path, digest in HISTORICAL.items()]
    require(manifest['historical_inputs'] == expected, 'historical hash inventory changed')
    for path, digest in HISTORICAL.items():
        require(hashlib.sha256((root / path).read_bytes()).hexdigest() == digest, f'historical bytes changed: {path}')
    base = load_strict_json(root / BASE)
    columns = base['operation_columns']
    require(len(columns) == 18 and len(set(columns)) == 18, 'historical columns invalid')
    require(manifest['operation_columns'] == columns, 'extension must retain all 18 columns in order')
    require([row[0] for row in base['operations']] == list(range(1, 58)), 'historical order changed')
    require(all(len(row) == 18 for row in base['operations']), 'historical row width changed')
    require(manifest['effective_inventory'] == {
        'base': BASE.as_posix(), 'historical_ids': list(range(1,58)), 'extension_ids': [58],
        'operation_count': 58, 'historical_stop_overlays': 'unchanged'}, 'effective inventory/order/stop overlay changed')
    rows = manifest['operations']
    require(len(rows) == 1 and len(rows[0]) == 18, 'exactly one complete extension row required')
    row = dict(zip(columns, rows[0], strict=True))
    require(type(row['id']) is int and row['id'] == 58, 'extension id must be 58')
    require(row['signature_rule'] == 'DIRECT_CALLER' and row['typehash'] == 'NONE', 'dismissal has no artist signature family')
    require(row['write_selector'] == hash_text(row['write_selector_preimage'])[:10], 'semantic write selector/preimage mismatch')
    old_selectors = {dict(zip(columns, value, strict=True))['write_selector'] for value in base['operations']}
    require(row['write_selector'] not in old_selectors, 'semantic selector collides with historical operation')
    types = manifest['types']
    require(types['Request'] == [{'name': n, 'type': t} for n,t in REQUEST], 'request field order/type changed')
    for name, fields in types.items():
        require(bool(fields) and len({f['name'] for f in fields}) == len(fields), f'duplicate or empty type fields: {name}')
        for field in fields:
            require(set(field) == {'name','type'}, f'unknown typed field member: {name}')
            require(field['type'] in types or re.fullmatch(r'bytes32|address|bool|uint8|uint16|uint64', field['type']) is not None,
                    f'invalid field width/type: {name}.{field["name"]}')
    short = {'bytes32':'b32', 'bool':'bool'}
    require(row['fields'] == ';'.join(n+':'+short[t] for n,t in REQUEST), 'row/request fields disagree')
    require(row['field_mask'] == f'0x{(1 << len(REQUEST))-1:06x}', 'request field mask changed')
    abi = manifest['abi']
    methods = abi['public_methods']
    require(len(methods) == 8, 'eight exact public methods required')
    require(len({m['signature'] for m in methods}) == len(methods), 'duplicate public signature')
    require(len({m['selector'] for m in methods}) == len(methods), 'public selector collision')
    interface_id = 0
    for method in methods:
        require(method['selector'] == hash_text(method['signature'])[:10], 'public selector/preimage mismatch')
        interface_id ^= int(method['selector'], 16)
    require(abi['interface_id'] == f'0x{interface_id:08x}', 'interface ID disagrees with public selectors')
    request_tuple = '('+','.join(t for _,t in REQUEST)+')'
    require(abi['write_signature'] == row['write']+'('+request_tuple+')', 'write does not use exact Request')
    require(abi['validation_signature'] == 'identityContestDismissalContext('+request_tuple+')', 'invented validation surface')
    require(row['validation_selector'] == hash_text(abi['validation_signature'])[:10], 'validation selector mismatch')
    require(abi['write_signature'] in {m['signature'] for m in methods}, 'actual public write missing')
    recipe = manifest['recipe']
    require(recipe['operation_id'] == 58 and recipe['owner'] == 'identity_authority', 'operation has wrong owner')
    require(all(recipe[k] == '0x04' for k in ('snapshot_mask','read_mask','write_mask')), 'dismissal must use Identity-only masks')
    require(recipe['payout_access'] == 'NONE', 'operation58 may not access Payout')
    require(recipe['authority_classes'] == [1,2], 'canonical class1/2 authority changed')
    require(recipe['supported_prior_statuses'] == [1] and recipe['supported_incumbent_classes'] == [1], 'unsupported restoration advertised')
    domains = manifest['domains']
    require(len(domains) == 7 and len({d['preimage'] for d in domains}) == 7, 'domain inventory incomplete/duplicated')
    for domain in domains:
        require(domain['hash'] == hash_text(domain['preimage']), 'domain preimage/hash mismatch')
    events = manifest['events']
    require(len(events) == 2 and len({e['name'] for e in events}) == 2, 'event inventory incomplete/duplicated')
    for event in events:
        require(event['emitter'] == 'identity_authority' and event['schema_version'] == 1, 'event owner/schema drift')
        fields = event['fields']
        require(len({f['name'] for f in fields}) == len(fields), 'duplicate event field')
        require(sum(f['indexed'] for f in fields) <= 3 and all(type(f['indexed']) is bool for f in fields), 'invalid indexed fields')
        signature = event['name']+'('+','.join(f['type'] for f in fields)+')'
        require(event['signature'] == signature and event['topic0'] == hash_text(signature), 'event signature/topic mismatch')
    event_map = {e['name']: e for e in events}
    require(row['events'] == 'ArtistIdentityContestDismissed', 'primary event changed')
    join = manifest['record_event_join']
    record_fields = manifest['hash_recipes']['record'][4:]
    inputs = {'Request.'+n for n,_ in REQUEST} | set(record_fields[1:])
    require(set(join['fields']) == inputs, 'record event join omits or invents a preimage field')
    event_fields = {f['name'] for f in event_map[join['record']]['fields']}
    require(set(join['fields'].values()) <= event_fields, 'record join names absent event fields')
    require(join['environment'] == ['chainId','registry','identityOwner'], 'record environment drift')
    require('revisionContinuationHead' not in record_fields, 'circular record/continuation preimage')
    cause_fields = event_map['ArtistIdentityContestCauseCaptured']['fields'][3:]
    require([{k:f[k] for k in ('name','type')} for f in cause_fields] == types['CauseFacts'][1:], 'cause event cannot reconstruct CauseFacts')
    replay = manifest['replay']
    require([r['surface'] for r in replay] == ['identity_authority.replay.contest_resolution',
        'identity_authority.replay.dismissal_action','identity_authority.replay.identity_revision_continuation'], 'replay inventory changed')
    require(replay[0]['scope'] == ['artistId','causeHash'], 'cause replay scope changed')
    require(replay[1]['scope'] == ['actionId','scopeHash','oldValueHash','newValueHash'], 'action replay is not per-call')
    require(all(r['cell'] == ['dismissalRecordHash','revision+1',1,2] for r in replay[:2]), 'resolution replay cell changed')
    require(manifest['archive']['operation_id'] == 58 and manifest['archive']['owner'] == recipe['owner'], 'Archive operation/owner mismatch')
    prerequisites = manifest['source_prerequisites']
    require([p['id'] for p in prerequisites] == ['cause_capture','rotation_closure','identity_revision_continuation',
        'payout_continuation','operative_reads','effective_source_configuration'], 'source prerequisites incomplete')
    require(prerequisites[0]['operations'] == [31,33] and prerequisites[3]['operations'] == [18], 'cause or lazy payout recipe missing')
    require(manifest['implementation_stops'] == STOPS and row['implementation_stop'] == STOPS, 'implementation stop overlay changed')
    # The reviewed design pins normative prose, struct order, optional fields and
    # remaining recipes beyond the independently derived structural checks above.
    require(canonical_digest(manifest) == DESIGN_SHA256, 'reviewed design changed; a new reviewed version is required')
    return base['operations'] + rows


def check(root: Path, require_implementation: bool = False) -> dict[str, Any]:
    try:
        manifest = load_strict_json(root / MANIFEST)
        rows = validate(root, manifest)
        if require_implementation:
            raise ExtensionError('implementation acceptance unavailable: '+', '.join(STOPS))
        return {'effective_operations':len(rows), 'historical_operations':57, 'extension_operations':1,
                'historical_inputs':len(HISTORICAL), 'status':manifest['status'], 'implementation_accepted':False}
    except (KeyError, TypeError, IndexError, OSError, MatrixError) as exc:
        raise ExtensionError(f'invalid extension input: {exc}') from exc


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--require-implementation', action='store_true', help='fail while current-source/configuration and runtime acceptance are pending')
    args = parser.parse_args(argv)
    try:
        print(json.dumps(check(args.root.resolve(), args.require_implementation), sort_keys=True))
        return 0
    except ExtensionError as exc:
        print(f'artist operation extension check failed: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
