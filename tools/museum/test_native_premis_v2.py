"""Concrete V4 native receipts and RIGHTS notices; no source-verifier mocks."""
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from lxml import etree

from . import native_premis_v2 as native
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .bagit import write_tree
from .package_v2 import _dependencies
from .object_dossier import _ref


def parsed(raw): return loads(raw, maximum=native.v1.dossier.MAX_BYTES, canonical=True)


def plan_for(original):
    files = dict(original.files); pin = original.manifest_hash
    inventory = parsed(native.v1.inventory._extract(files, pin).inventory)
    supplemental = native._source_inventory(files, pin)
    return dumps({'version': '2', 'kind': native.PLAN_KIND, 'sourceManifestHash': pin,
        'selected': [{'occurrenceId': r['occurrenceId'], 'selector': r['selector']}
            for r in inventory['occurrences'] if r['family'] in ('WORK', 'LOAN', 'OWNER_UNKNOWN')],
        'selectedRights': [{'occurrenceId': r['occurrenceId'], 'selector': r['selector']}
            for r in supplemental['occurrences'] if r['family'] == native.FAMILY]})


@lru_cache(maxsize=1)
def supplied():
    from .test_native_work_lido_v1 import supplied as original_case
    original, _ = original_case()
    return original, plan_for(original)


@lru_cache(maxsize=1)
def complete():
    original, plan = supplied()
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        result = native.build(dict(original.files), original.manifest_hash, plan, keccak256(plan), disclosure='public')
    return original, plan, result


def _empty_inventory(pin):
    return dumps({'profileHash': native.v1.inventory.PROFILE_HASH,
        'sourceManifestHash': pin, 'occurrences': [], 'fields': []})


@lru_cache(maxsize=1)
def rights_case():
    """Actual PublicRightsSource replay at the private family-formatting seam.

    These files are not a V4 package. The separate complete() fixture exercises
    public V4 admission; this smaller source permits exact historical notices.
    """
    from .test_public_rights_source import PublicRightsFixture
    from .public_history_rpc import PublicReplayTransport
    from tools.metadata import rights_profile
    fixture = PublicRightsFixture(token=True)
    fixture.append('collection', 'denied', block=3)
    def declaration(value):
        example = rights_profile.examples()[1]
        value.update(basis=example['basis'], instrument=example['instrument'],
            licensor=example['licensor'], effectiveDates={'start': '9999-01-01', 'end': None})
        value['grants']['print']['status'] = 'denied'
        value['grants']['reproduction'] = example['grants']['reproduction']
    fixture.append('token', 'unspecified', block=4, edit=declaration)
    source = fixture.source(); raw = source.snapshot(); transcript = source.transcript()
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        replay = native.rights_source.PublicRightsSource(source.anchor_bytes,
            PublicReplayTransport(transcript, keccak256(transcript)))
        assert replay.snapshot() == raw
    snapshot = parsed(raw); pin = keccak256(raw)
    relative = 'concrete-rights/source/snapshot.json'
    files = {native.PRIOR + relative: raw, native.RIGHTS_JOIN:
        dumps({'snapshotPath': relative, 'snapshotHash': pin})}
    supplemental = native._source_inventory(files, pin)
    plan = dumps({'version': '2', 'kind': native.PLAN_KIND, 'sourceManifestHash': pin,
        'selected': [], 'selectedRights': [{'occurrenceId': r['occurrenceId'], 'selector': r['selector']}
            for r in supplemental['occurrences'] if r['family'] == native.FAMILY]})
    inventory = _empty_inventory(pin)
    result = native._derive(files, pin, plan, keccak256(plan), inventory_raw=inventory)
    return files, pin, plan, inventory, result, snapshot


@lru_cache(maxsize=1)
def receipt_case():
    """Concrete Owner and Independent replays, then private XML formatting.

    Transaction senders are fixture observations installed before capture.
    The native source validates signed-record correspondence, not signatures.
    No source bytes or native authority fields are replaced after capture.
    """
    from .test_owner_catalog_source import Fixture, A
    from .test_public_condition_source import PublicConditionFixture
    from .chain_rpc import ReplayTransport
    from .public_history_rpc import PublicReplayTransport
    owner = Fixture(); independent = PublicConditionFixture()
    submitter = A(99)
    for fixture in (owner, independent):
        for receipt in fixture.receipts.values(): receipt['from'] = submitter
    owner_source = owner.source(); owner_raw = owner_source.snapshot(); owner_transcript = owner_source.transcript()
    independent_source = independent.source(); independent_raw = independent_source.snapshot()
    independent_transcript = independent_source.transcript()
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        assert type(owner_source)(owner_source.anchor_bytes,
            ReplayTransport(owner_transcript, keccak256(owner_transcript))).snapshot() == owner_raw
        assert type(independent_source)(independent_source.anchor_bytes,
            PublicReplayTransport(independent_transcript, keccak256(independent_transcript))).snapshot() == independent_raw
    files = {'owner.json': owner_raw, 'condition.json': independent_raw}
    sources = native._Sources(files); rows, originals = [], {}
    for path in files:
        snapshot = parsed(files[path])
        for index, original in enumerate(snapshot['records']):
            if path == 'owner.json':
                if not original['receipt'][5] or original['record'][3][0] != '2': continue
                kind, family, host = 'native_owner_family', 'OWNER_UNKNOWN', snapshot['host']
            else:
                if original['lane'] != 'INDEPENDENT': continue
                kind, family, host = 'native_independent_condition', 'CONDITION', original['host']
            ref = sources.ref(path, '/records/' + str(index))
            oid = keccak256(dumps(ref)); originals[oid] = original
            rows.append({'occurrenceId': oid, 'family': family,
                'selector': {'kind': kind, 'host': host, 'recordHash': original['recordHash']},
                'authority': original['authority'], 'currentness': None, 'selection': None,
                'original': ref, 'domains': [{'name': 'original', 'source': ref}]})
    objects, diagnostics, _ = native.v1._objects(sources, rows, {r['occurrenceId'] for r in rows})
    assert not diagnostics
    model = native.v1.PinnedPremis(native.MODEL_ROOT, native.v1.XSD_PROFILE_BYTES,
        profile_hash=native.v1.XSD_PROFILE_HASH)
    result = native._extend_xml(sources, objects, [], model)
    return files, rows, originals, result, submitter, owner_transcript, independent_transcript


class NativePremisV2Tests(unittest.TestCase):
    def test_real_v4_rights_and_publication_sources_are_distinct_documentary_records(self):
        original, plan, result = complete()
        self.assertGreater(int(result.report['rightsStatementCount']), 0)
        self.assertGreater(int(result.report['eventCount']), int(result.report['rightsStatementCount']))
        root = etree.fromstring(result.files['premis/objects.xml']); ns = {'p': native.NS}
        self.assertFalse(root.xpath('//p:rightsGranted | //p:termOfGrant | //p:copyrightInformation | //p:licenseInformation', namespaces=ns))
        self.assertEqual(set(root.xpath('//p:eventType/text()', namespaces=ns)), {'native_record_publication'})
        self.assertEqual(int(result.report['rightsStatementCount']), len(root.xpath('//p:rightsStatement', namespaces=ns)))
        self.assertEqual(original.report['packetRequirementCount'], '19')
        self.assertEqual(original.report['dossierRequirementCount'], '49')
        self.assertFalse(result.report['claims']['underlyingActivityPerformanceProven'])
        self.assertFalse(result.report['claims']['rightsGranted'])

    def test_actual_relayed_principals_are_not_transaction_submitters(self):
        _, rows, originals, result, submitter, owner_transcript, independent_transcript = receipt_case()
        raw, proofs, _, events, agents, _, _ = result
        self.assertIn('"from":"' + submitter + '"', owner_transcript.decode())
        self.assertIn('"from":"' + submitter + '"', independent_transcript.decode())
        self.assertEqual(len(events), len(rows))
        roles = set()
        for event, agent in zip(events, agents):
            original = originals[event['occurrenceId']]; receipt = original['receipt']
            owner = len(receipt) == 13
            expected = 'original_owner_authorizing_account' if owner else 'original_attestor_account'
            self.assertEqual(agent['role'], expected); roles.add(expected)
            self.assertEqual(agent['name'], receipt[1]); self.assertNotEqual(agent['name'], submitter)
            self.assertEqual(event['receiptAccountRole'], expected)
            self.assertEqual(event['receiptAccountAgentId'], agent['id'])
            self.assertFalse(event['transactionSubmitterInferred'])
            if owner:
                self.assertIs(receipt[5], True)
                relay = next(p for p in proofs if p['occurrenceId'] == event['occurrenceId']
                    and p['rule'].endswith('original-authority-field-not-current-role'))
                self.assertEqual(relay['sources'][0]['pointer'], '/receipt/5')
                self.assertIs(parsed(hex_bytes(relay['sources'][0]['exactHex'])), True)
        self.assertEqual(roles, {'original_owner_authorizing_account', 'original_attestor_account'})
        self.assertNotIn(submitter.encode(), raw)

    def test_publication_dates_use_original_receipt_not_effective_or_examination_dates(self):
        _, _, originals, result, _, _, _ = receipt_case()
        raw, proofs, _, events, _, _, _ = result; root = etree.fromstring(raw)
        for event in events:
            original = originals[event['occurrenceId']]
            date_index = 2 if len(original['receipt']) == 13 else 3
            stamp = int(original['receipt'][date_index])
            self.assertNotEqual(stamp, int(original['record'][-1]))
            expected = (datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=stamp)).isoformat().replace('+00:00', 'Z')
            node = root.xpath('//p:event[p:eventIdentifier/p:eventIdentifierValue=$id]',
                namespaces={'p': native.NS}, id=event['id'])[0]
            self.assertEqual(node.find('{'+native.NS+'}eventDateTime').text, expected)
            proof = next(p for p in proofs if p['occurrenceId'] == event['occurrenceId']
                and p['rule'].endswith('receipt-recorded-at-utc'))
            self.assertEqual(proof['sources'][0]['pointer'], '/receipt/' + str(date_index))
        self.assertNotIn(b'fixity check', raw)
        self.assertEqual(set(root.xpath('//p:eventType/text()', namespaces={'p': native.NS})), {'native_record_publication'})

    def test_original_general_receipt_uses_its_own_account_class_and_date_layout(self):
        # Concrete original GeneralV2 replay followed by the private family
        # formatter; no semantic profile or V4 membership is fabricated.
        from .test_general_attestation_source_v2 import Fixture
        from .chain_rpc import ReplayTransport
        fixture = Fixture(); source = fixture.reader(); raw = source.snapshot(); transcript = source.transcript()
        with patch('socket.socket', side_effect=AssertionError('network forbidden')):
            self.assertEqual(type(source)(source.anchor_bytes,
                ReplayTransport(transcript, keccak256(transcript))).snapshot(), raw)
        snapshot = parsed(raw); files = {'general.json': raw}; sources = native._Sources(files)
        rows = []
        for index, original in enumerate(snapshot['records']):
            ref = sources.ref('general.json', '/records/' + str(index))
            rows.append({'occurrenceId': keccak256(dumps(ref)), 'family': 'GENERAL_ORIGINAL',
                'selector': {'kind': 'native_general_attestation', 'host': snapshot['host'], 'recordHash': original['recordHash']},
                'authority': {'receipt': original['receipt'], 'qualification': original['qualification']},
                'currentness': None, 'selection': None, 'original': ref,
                'domains': [{'name': 'original', 'source': ref}]})
        objects, _, _ = native.v1._objects(sources, rows, {r['occurrenceId'] for r in rows})
        model = native.v1.PinnedPremis(native.MODEL_ROOT, native.v1.XSD_PROFILE_BYTES, profile_hash=native.v1.XSD_PROFILE_HASH)
        _, proofs, _, events, agents, _, _ = native._extend_xml(sources, objects, [], model)
        self.assertEqual(len(events), len(snapshot['records']))
        for row, original, event, agent in zip(rows, snapshot['records'], events, agents):
            self.assertEqual(agent['name'], original['receipt'][0])
            self.assertEqual(agent['role'], 'original_general_recorder_account')
            self.assertEqual(event['recordedAtSource'], '/receipt/3')
            proof = next(p for p in proofs if p['occurrenceId'] == row['occurrenceId']
                and p['rule'].endswith('original-authority-field-not-current-role'))
            self.assertEqual(proof['sources'][0]['pointer'], '/receipt/1')
            self.assertEqual(parsed(hex_bytes(proof['sources'][0]['exactHex'])), original['receipt'][1])

    def test_real_rights_scope_history_does_not_inherit_collection_permission(self):
        _, _, _, _, result, snapshot = rights_case()
        inventory = parsed(result.files['premis/inventory.json'])
        original_by_hash = {r['recordHash']: r for r in snapshot['records']}
        supplemental = parsed(result.files['premis/supplemental-source-inventory.json'])
        by_id = {r['occurrenceId']: r for r in supplemental['occurrences']}
        self.assertEqual(len(inventory['rightsStatements']), 4)
        self.assertEqual(len({r['id'] for r in inventory['rightsStatements']}), 4)
        root = etree.fromstring(result.files['premis/objects.xml'])
        for statement in inventory['rightsStatements']:
            source = by_id[statement['occurrenceId']]
            original = original_by_hash[source['selector']['recordHash']]
            self.assertEqual(statement['acts'], original['value']['grants'])
            self.assertEqual(statement['selectedAtSource'],
                snapshot['scopes'][statement['scope']]['current'][0] == original['recordHash'])
            xml = root.xpath('//p:rightsStatement[p:rightsStatementIdentifier/p:rightsStatementIdentifierValue=$id]',
                namespaces={'p': native.NS}, id=statement['id'])[0]
            notes = xml.xpath('p:otherRightsInformation/p:otherRightsNote/text()', namespaces={'p': native.NS})
            for use in native.USES:
                self.assertIn(use + ' original status: ' + original['value']['grants'][use]['status'], notes)
            self.assertFalse(xml.xpath('p:linkingObjectIdentifier|p:rightsGranted', namespaces={'p': native.NS}))
        current_token = next(r for r in inventory['rightsStatements'] if r['scope'] == 'token' and r['selectedAtSource'])
        self.assertEqual(current_token['acts']['exhibition']['status'], 'unspecified')
        self.assertEqual(current_token['acts']['print']['status'], 'denied')
        self.assertEqual(snapshot['effectiveGrants']['exhibition'], 'unspecified')
        self.assertFalse(result.report['claims']['effectiveDateApplicabilityAssessed'])

    def test_declared_licensor_instrument_and_dates_are_not_holder_or_grant(self):
        _, _, _, _, result, _ = rights_case(); inventory = parsed(result.files['premis/inventory.json'])
        root = etree.fromstring(result.files['premis/objects.xml']); ns = {'p': native.NS}
        self.assertFalse(root.xpath('//p:rightsGranted|//p:termOfGrant|//p:licenseInformation|//p:copyrightInformation', namespaces=ns))
        self.assertIn('9999-01-01', root.xpath('//p:otherRightsApplicableDates/p:startDate/text()', namespaces=ns))
        self.assertFalse(root.xpath('//p:otherRightsApplicableDates/p:endDate', namespaces=ns))
        by_occurrence = {}
        for agent in inventory['agents']:
            if agent['rightsId'] is not None:
                statement = next(s for s in inventory['rightsStatements'] if s['id'] == agent['rightsId'])
                event = next(e for e in inventory['events'] if e['occurrenceId'] == statement['occurrenceId'])
                account = next(a for a in inventory['agents'] if a['id'] == event['receiptAccountAgentId'])
                self.assertNotEqual(account['id'], agent['id'])
                self.assertEqual(account['role'], 'original_metadata_recorder_account')
                self.assertEqual(agent['role'], 'declared_licensor')
                by_occurrence[statement['occurrenceId']] = (account, agent)
        self.assertTrue(any(a['name'] == b['name'] for a, b in by_occurrence.values()))
        self.assertTrue(any(a['name'] != b['name'] and b['kind'] == 'institution' for a, b in by_occurrence.values()))
        instrument_proofs = [p for p in parsed(result.files['premis/provenance.json'])['rows']
            if p['rule'].endswith('original-instrument-reference-not-bytes')]
        self.assertTrue(instrument_proofs)
        self.assertTrue(all(p['sources'][0]['pointer'].startswith('/value/instrument/') for p in instrument_proofs))
        self.assertFalse(result.report['claims']['namedLicensorIdentityProven'])

    def test_every_supplemental_original_leaf_is_preserved_before_selection(self):
        files, _, _, _, result, snapshot = rights_case()
        inventory = parsed(result.files['premis/supplemental-source-inventory.json'])
        resolver = native.v1._Sources(files)
        def leaves(value, pointer=''):
            if isinstance(value, dict) and value:
                out = []
                for key in sorted(value):
                    out.extend(leaves(value[key], pointer + '/' + key.replace('~', '~0').replace('/', '~1')))
                return out
            if isinstance(value, list) and value:
                return [entry for i, v in enumerate(value) for entry in leaves(v, pointer + '/' + str(i))]
            return [(pointer, '0x' + dumps(value).hex())]
        expected = []
        for row in inventory['occurrences']:
            self.assertEqual(row['domains'], [{'name': 'retained_source', 'source': row['original']}])
            original = resolver.resolve(row['original'])
            expected.extend((row['occurrenceId'], pointer, raw) for pointer, raw in leaves(original))
        self.assertEqual(expected, [(f['occurrenceId'], f['pointer'], f['exactHex']) for f in inventory['fields']])
        self.assertEqual([r['selector']['scope'] for r in inventory['occurrences'][:2]], ['collection', 'token'])
        self.assertEqual([r['selector']['recordHash'] for r in inventory['occurrences'][2:]],
            [r['recordHash'] for r in snapshot['records']])
        self.assertFalse(result.report['claims']['originalFieldDenominatorExpanded'])

    def test_each_provenance_field_and_final_xpath_resolves_without_constant_promotion(self):
        original, _, public = complete()
        rights_files, _, _, _, family, _ = rights_case()
        for files, result in ((dict(original.files), public), (rights_files, family)):
            resolver = native.v1._Sources(files); root = etree.fromstring(result.files['premis/objects.xml'])
            proofs = parsed(result.files['premis/provenance.json'])['rows']; mapped = set()
            for proof in proofs:
                target = proof['target']
                self.assertEqual(target['hash'], keccak256(result.files[target['path']]))
                self.assertEqual([node.text for node in root.xpath(target['xpath'], namespaces={'premis': native.NS})], [proof['targetValue']])
                for source in proof['sources']:
                    value = resolver.resolve(source['sourceReference'])
                    if source['domain'] in ('original_identity', 'derived_bytes'): continue
                    if isinstance(value, bytes): value = parsed(value)
                    exact = native.v1.pointers._resolve_value(value, source['pointer'], 'json')
                    self.assertEqual(source['exactHex'], '0x' + dumps(exact).hex())
                    mapped.add((proof['occurrenceId'], source['domain'], source['pointer']))
                if proof['rule'].endswith(('publication-type', 'documentary-rights-basis', 'agent-type-no-personhood-inference')):
                    self.assertEqual({s['domain'] for s in proof['sources']}, {'original_identity'})
            coverage = parsed(result.files['premis/coverage.json'])
            accounted = {(f['occurrenceId'], f['domain'], f['pointer'])
                for f in coverage['fields'] + coverage['supplementalFields'] if f['disposition'] == 'mapped'}
            self.assertEqual(accounted, mapped)

    def test_rehashed_rights_original_contradictions_reject(self):
        files, pin, _, _, _, snapshot = rights_case()
        path = native.PRIOR + parsed(files[native.RIGHTS_JOIN])['snapshotPath']
        for label, mutate in (
            ('payload', lambda v: v['records'][0].update(payloadHex='0x7b7d')),
            ('receipt authority', lambda v: v['records'][0]['receipt'].__setitem__(2, '1')),
            ('schema', lambda v: v['records'][0]['receipt'].__setitem__(6, '0x' + '11' * 32)),
            ('canonicalization', lambda v: v['records'][0]['record'][2].__setitem__(2, '0x' + '11' * 32)),
            ('declared field', lambda v: v['records'][0]['value'].update(basis='copyright')),
            ('record id', lambda v: v['records'][0].update(recordHash='0x' + '11' * 32)),
            ('selection publisher', lambda v: v['scopes']['collection']['history'][0].__setitem__(10, '0x' + '11' * 20)),
            ('subject', lambda v: v['scopes']['token'].update(subjectId=v['scopes']['collection']['subjectId'])),
        ):
            changed = deepcopy(snapshot); mutate(changed); retained = dict(files); retained[path] = dumps(changed)
            join = parsed(retained[native.RIGHTS_JOIN]); join['snapshotHash'] = keccak256(retained[path]); retained[native.RIGHTS_JOIN] = dumps(join)
            with self.subTest(label=label), self.assertRaises(MuseumError): native._source_inventory(retained, pin)

    def test_empty_export_selection_preserves_all_original_rights_scopes_and_fields(self):
        files, pin, plan, inventory, original, _ = rights_case()
        value = parsed(plan); value['selectedRights'] = []; plan = dumps(value)
        result = native._derive(files, pin, plan, keccak256(plan), inventory_raw=inventory)
        self.assertEqual(result.report['status'], 'empty_selection')
        self.assertEqual(result.report['eventCount'], '0'); self.assertEqual(result.report['rightsStatementCount'], '0')
        self.assertNotIn('premis/objects.xml', result.files)
        self.assertEqual(result.files['premis/supplemental-source-inventory.json'], original.files['premis/supplemental-source-inventory.json'])
        self.assertFalse(any(f['disposition'] == 'mapped' for f in parsed(result.files['premis/coverage.json'])['supplementalFields']))

    def test_exact_selection_plan_pin_and_scope_cannot_become_notice(self):
        files, pin, plan, inventory, result, _ = rights_case()
        scope = parsed(result.files['premis/supplemental-source-inventory.json'])['occurrences'][0]
        for label in ('selector', 'scope', 'path', 'duplicate', 'version'):
            value = parsed(plan)
            if label == 'selector': value['selectedRights'][0]['selector']['recordIndex'] = '999'
            elif label == 'scope': value['selectedRights'][0] = {k: scope[k] for k in ('occurrenceId', 'selector')}
            elif label == 'path': value['selectedRights'][0]['payloadPath'] = 'caller-selected.json'
            elif label == 'duplicate': value['selectedRights'].append(deepcopy(value['selectedRights'][0]))
            else: value['version'] = '1'
            raw = dumps(value)
            with self.subTest(label=label), self.assertRaises(MuseumError):
                native._derive(files, pin, raw, keccak256(raw), inventory_raw=inventory)
        with self.assertRaisesRegex(MuseumError, 'plan pin'):
            native._derive(files, pin, plan, '0x' + '11' * 32, inventory_raw=inventory)

    def test_missing_rights_source_is_not_an_absent_notice_or_generated_scope(self):
        # Deliberately missing private-family input, never claimed valid V4.
        pin = '0x' + '11' * 32
        inventory = native._source_inventory({}, pin)
        self.assertEqual(inventory['status'], 'not_retained')
        self.assertEqual(inventory['occurrences'], []); self.assertEqual(inventory['fields'], [])
        self.assertEqual(inventory['sourceReferences'], [])
        files, _, plan, _, _, _ = rights_case(); value = parsed(plan); value['sourceManifestHash'] = pin; plan = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'occurrence/selector'):
            native._derive({}, pin, plan, keccak256(plan), inventory_raw=_empty_inventory(pin))

    def test_unknown_receipt_or_calendar_does_not_infer_performed_activity(self):
        _, rows, originals, _, _, _, _ = receipt_case()
        row = rows[0]; original = deepcopy(originals[row['occurrenceId']])
        self.assertIsNone(native._publication(row, {'receipt': [], 'record': []}))
        index = 2 if len(original['receipt']) == 13 else 3
        original['receipt'][index] = str(2**64 - 1)
        self.assertEqual(native._publication(row, original), {'status': 'publication_date_outside_xml_calendar'})
        # A generic record type alone never identifies the underlying event.
        original = deepcopy(originals[row['occurrenceId']]); original['record'][0] = keccak256(b'FIXITY_CYCLE_COMPLETED')
        self.assertEqual(native._publication(row, original)['agentRole'], 'original_owner_authorizing_account')

    def test_recommitted_v4_derived_authority_change_still_replays_originals(self):
        original, plan, _ = complete(); files = dict(original.files)
        path = 'canonical/inputs/source-inventory.json'; value = parsed(files[path]); value['rows'][0]['authority']['invented'] = True
        files[path] = dumps(value); manifest = parsed(files['manifest.json'])
        manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
        files['manifest.json'] = dumps(manifest); pin = keccak256(files['manifest.json'])
        value = parsed(plan); value['sourceManifestHash'] = pin; plan = dumps(value)
        with self.assertRaises(MuseumError): native.build(files, pin, plan, keccak256(plan), disclosure='public')

    def test_portable_original_xsd_reproduces_rights_events_and_agents_offline(self):
        files, pin, plan, inventory, expected, _ = rights_case()
        deps = {p.removeprefix('dependencies/'): raw for p, raw in _dependencies(native.MODEL_ROOT, recorded=True, premis=True).items()}
        with TemporaryDirectory() as temporary:
            root = Path(temporary) / 'model'; write_tree(deps, root); read = Path.read_bytes
            def local_only(path):
                if path.resolve().is_relative_to(native.MODEL_ROOT.resolve()): raise AssertionError('repository model fallback')
                return read(path)
            with patch.object(Path, 'read_bytes', local_only), patch('socket.socket', side_effect=AssertionError('network forbidden')):
                result = native._derive(files, pin, plan, keccak256(plan), root, inventory_raw=inventory)
            self.assertEqual(result, expected)

    def test_public_guard_precedes_source_mapping_reads(self):
        class Trap:
            def __iter__(self): raise AssertionError('private input read')
        for call in (lambda: native.build(Trap(), 'bad', b'bad', 'bad', disclosure='restricted'),
                lambda: native.source_inventory(Trap(), 'bad', disclosure='restricted')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'): call()


if __name__ == '__main__': unittest.main()
