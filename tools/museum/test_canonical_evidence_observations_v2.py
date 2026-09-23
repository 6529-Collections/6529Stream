"""Internal observation controls plus concrete script and PREMIS child replay.

Small maps are explicitly post-verification adapter inputs, not purported V4
or catalogue packages. Real child tests use their complete concrete verifiers.
No concrete source/package verifier is mocked.
"""
from copy import deepcopy
import unittest
from unittest import mock

from . import canonical_evidence_observations_v2 as join
from . import canonical_script_observations_v1 as scripts
from . import collection_script_package_v1 as script_package
from . import independent_catalog_source as catalog
from . import object_dossier as package
from . import premis_retained as retained
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .test_canonical_script_observations_v1 import helper_base, reseal
from .test_collection_script_package_v1 import build
from .test_collection_script_source_v1 import CollectionScriptFixture
from .test_premis_retained import Fixture as PremisFixture


def parsed(files, path):
    return loads(files[path], maximum=join.MAX_BYTES, canonical=True)


def descriptor(result, family):
    return next(row for row in result['sources'] if row['family'] == family)


def properties_base(files):
    """Labelled minimal canonical adapter map aligned to a real catalogue."""
    anchor = parsed(files, 'source/anchor.json')
    reference = {key: anchor[key] for key in join.observations.COMMON if key in anchor}
    reference.update(collectionId=anchor['scopeKey'], tokenId='41',
        deploymentEvidenceHash=anchor['deploymentEvidenceHash'])
    codes = {row['params'][0]: keccak256(bytes.fromhex(row['result'][2:]))
        for row in parsed(files, 'source/transcript.json')['calls'] if row['method'] == 'eth_getCode'}
    row = {'kind': 'native', 'name': 'canonical-helper', 'context': reference,
        'calls': [], 'events': [], 'runtimePins': {anchor['core']: codes[anchor['core']]},
        'provenance': 'synthetic_fixture'}
    config = {'host': '0x' + 'ee' * 20, 'artistRegistry': '0x' + 'dd' * 20,
        'schemas': anchor['schemas'], 'store': anchor['store']}
    return {'report.json': dumps({'sourceState': reference}),
        'canonical/report.json': dumps({'sourceState': reference}),
        'canonical/input/acquisition/inputs/work/metadata/anchor.json': dumps(config),
        'canonical/input/acquisition/source-observations.json': dumps([row])}


def property_observations(script_files, *, scope='7', calls=(), runtime_override=None):
    """Small original-observation shape for join tests, never a verified child."""
    a = parsed(script_files, 'source/anchor.json')
    script_calls = parsed(script_files, 'source/transcript.json')['calls']
    core_code = next(row['result'] for row in script_calls
        if row['method'] == 'eth_getCode' and row['params'][0] == a['core'])
    codes = {a['core']: core_code, '0x' + 'aa' * 20: '0x6001',
        '0x' + 'ee' * 20: '0x6002', '0x' + 'bb' * 20: '0x6003'}
    if runtime_override: codes.update(runtime_override)
    anchor = {key: a[key] for key in join.observations.COMMON if key != 'collectionId'}
    anchor.update(profile=catalog.PROFILE, deploymentEvidenceHash=a['deploymentEvidenceHash'],
        scopeKey=scope, host='0x' + 'aa' * 20, schemas='0x' + 'ee' * 20,
        store='0x' + 'bb' * 20, codePins=[{'address': address,
            'runtimeHash': keccak256(bytes.fromhex(raw[2:]))} for address, raw in codes.items()])
    block = {'blockHash': a['blockHash'], 'requireCanonical': True}
    transcript = {'version': 1, 'calls': [{'method': 'eth_getCode',
        'params': [address, block], 'result': raw} for address, raw in codes.items()] + list(calls)}
    files = {'source/anchor.json': dumps(anchor), 'source/transcript.json': dumps(transcript)}
    property_reseal(files)
    return files


def property_reseal(files, *, anchor=None, transcript=None):
    """Reseal only labelled internal inputs; this does not confer admission."""
    if anchor is not None: files['source/anchor.json'] = dumps(anchor)
    if transcript is not None: files['source/transcript.json'] = dumps(transcript)
    a = parsed(files, 'source/anchor.json')
    snapshot = parsed(files, 'source/snapshot.json') if 'source/snapshot.json' in files else {}
    snapshot.update(profile=catalog.PROFILE, profileHash=catalog.PROFILE_HASH,
        mode='synthetic_fixture', evidence='synthetic_fixture', environment=a['environment'],
        anchorHash=keccak256(files['source/anchor.json']),
        transcriptHash=keccak256(files['source/transcript.json']), scopeKey=a['scopeKey'],
        sourceState={key: a[key] for key in ('chainId', 'core', 'scopeKey', 'blockHash', 'blockNumber')})
    files['source/snapshot.json'] = dumps(snapshot)


class CanonicalEvidenceObservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result, _, _ = build(CollectionScriptFixture())
        cls.script = dict(result.files)
        script_package.verify(cls.script, result.manifest_hash)
        a = PremisFixture().artifacts()
        cls.properties = retained.build(a['anchor'], a['transcript'], a['plan'], a['files'],
            anchor_hash=a['anchorHash'], transcript_hash=a['transcriptHash'],
            source_hash=a['sourceHash'], plan_hash=a['planHash'], profile_hash=a['profileHash'],
            provenance='synthetic_fixture', disclosure='public')
        retained.verify(cls.properties, keccak256(cls.properties['manifest.json']))

    def setUp(self):
        self.script = dict(self.__class__.script)
        self.base = helper_base(self.script)

    def optional_call(self, result='0x01'):
        a = parsed(self.script, 'source/anchor.json')
        return {'method': 'eth_call', 'params': [{'to': a['core'],
            'data': '0xdeadbeef', 'gas': '0x100000'},
            {'blockHash': a['blockHash'], 'requireCanonical': True}], 'result': result}

    def append_script(self, row):
        transcript = parsed(self.script, 'source/transcript.json')
        transcript['calls'].append(row)
        reseal(self.script, transcript=transcript)

    def test_absent_optionals_remain_absent_and_base_is_compared(self):
        result = join.reconcile(self.base)
        self.assertEqual([row['status'] for row in result['sources']], ['absent', 'absent'])
        self.assertIsNone(result['scriptProjection'])
        self.assertEqual(result['scriptUnavailable'], [])
        self.assertEqual(result['reconciliation']['report']['joinedSourceCount'], 1)
        self.assertFalse(result['claims']['requirementPromotionEstablished'])

    def test_real_script_child_scope_projection_and_exact_outer_references(self):
        before = (dict(self.base), dict(self.script))
        result = join.reconcile(self.base, self.script)
        row = descriptor(result, 'scripts')
        self.assertEqual(row['status'], 'joined')
        self.assertEqual(row['originalAnchor'], row['comparisonAnchor'])
        self.assertEqual(row['comparisonDerivations'], [])
        self.assertNotIn('tokenId', row['scope'])
        self.assertEqual(row['undeclaredConfiguration'], ['schemas', 'artistRegistry'])
        for kind, ref in row['sourceReferences'].items():
            path = 'scripts/source/' + kind + '.json'
            self.assertEqual(ref, package._ref(path, self.script[path.removeprefix('scripts/')]))
        self.assertEqual(result['scriptProjection']['sourceReference'], row['sourceReferences']['transcript'])
        self.assertEqual(before, (self.base, self.script))

    def test_real_premis_child_scope_is_explicit_and_original_source_state_unchanged(self):
        result = join.reconcile(properties_base(self.properties), properties_files=self.properties)
        row = descriptor(result, 'properties')
        anchor = parsed(self.properties, 'source/anchor.json')
        state = parsed(self.properties, 'source/snapshot.json')['sourceState']
        self.assertEqual(row['status'], 'joined')
        self.assertEqual(row['originalAnchor'], anchor)
        self.assertEqual(row['originalSourceState'], state)
        self.assertNotIn('collectionId', anchor)
        self.assertNotIn('environment', state)
        self.assertEqual(row['comparisonAnchor']['collectionId'], anchor['scopeKey'])
        self.assertEqual(row['comparisonDerivations'][0]['source']['pointer'], '/scopeKey')
        self.assertEqual(row['undeclaredConfiguration'], ['metadata', 'artistRegistry'])
        self.assertEqual(row['sourceReferences']['snapshot'], package._ref(
            'properties/source/snapshot.json', self.properties['source/snapshot.json']))
        self.assertGreater(len(row['runtimePins']), len(anchor['codePins']))
        for value in (row['originalAnchor'], row['originalSourceState'], row['comparisonAnchor'], row['scope']):
            self.assertNotIn('tokenId', value)

    def test_real_children_different_states_retained_unjoined_in_single_report(self):
        result = join.reconcile(self.base, self.script, self.properties)
        self.assertEqual(descriptor(result, 'scripts')['status'], 'joined')
        row = descriptor(result, 'properties')
        self.assertEqual(row['status'], 'unjoined')
        self.assertIn('state_differs:core', row['reasons'])
        self.assertEqual(len(result['reconciliation']['report']['sources']), 3)
        self.assertEqual(result['reconciliation']['hash'], keccak256(dumps(result['reconciliation']['report'])))

    def test_cross_optional_success_matches_and_conflict_rejects_without_base_query(self):
        call = self.optional_call()
        self.append_script(call)
        properties = property_observations(self.script, calls=[deepcopy(call)])
        result = join.reconcile(self.base, self.script, properties)
        self.assertEqual(descriptor(result, 'properties')['status'], 'unjoined')
        self.assertIn('configuration_differs:store', descriptor(result, 'properties')['reasons'])
        transcript = parsed(properties, 'source/transcript.json')
        transcript['calls'][-1]['result'] = '0x02'
        property_reseal(properties, transcript=transcript)
        with self.assertRaisesRegex(MuseumError, 'conflicting|contradict|differs'):
            join.reconcile(self.base, self.script, properties)

    def test_cross_optional_runtime_collision_rejects(self):
        address = '0x' + 'aa' * 20
        block = self.optional_call()['params'][1]
        self.append_script({'method': 'eth_getCode', 'params': [address, block], 'result': '0x6004'})
        properties = property_observations(self.script)
        with self.assertRaisesRegex(MuseumError, 'runtime|code|pin'):
            join.reconcile(self.base, self.script, properties)

    def test_unavailable_occurrence_preserved_while_other_source_success_is_compared(self):
        call = self.optional_call()
        missing = deepcopy(call)
        del missing['result']
        missing['unavailable'] = {'kind': 'provider_error', 'code': -32000}
        self.append_script(missing)
        result = join.reconcile(self.base, self.script, property_observations(self.script, calls=[call]))
        index = len(parsed(self.script, 'source/transcript.json')['calls']) - 1
        self.assertEqual(result['scriptUnavailable'], [{'transcriptIndex': index, 'row': missing}])
        self.assertEqual(result['scriptProjection']['unavailableOriginalIndices'], [index])
        self.assertNotIn(index, result['scriptProjection']['projectedOriginalIndices'])
        self.assertEqual(result['originalObservationCount'], 1 + index + 1 + 5)

    def test_deployment_wide_scope_never_becomes_collection_zero(self):
        result = join.reconcile(self.base, properties_files=property_observations(self.script, scope='0'))
        row = descriptor(result, 'properties')
        self.assertEqual(row['scope']['kind'], 'deployment_wide')
        self.assertEqual(row['comparisonDerivations'], [])
        self.assertNotIn('collectionId', row['comparisonAnchor'])
        self.assertIn('state_undeclared:collectionId', row['reasons'])

    def test_repeated_properties_outcome_conflict_rejects(self):
        first = self.optional_call()
        second = dict(first, result='0x02')
        properties = property_observations(self.script, calls=[first, second])
        with self.assertRaisesRegex(MuseumError, 'repeated catalogue outcome'):
            join.reconcile(self.base, properties_files=properties)

    def test_wrong_snapshot_state_and_hash_are_not_report_authority(self):
        for key, value in (('transcriptHash', schema_id('unrelated transcript')),
                ('sourceState', {'chainId': '1'})):
            with self.subTest(key=key):
                properties = property_observations(self.script)
                snapshot = parsed(properties, 'source/snapshot.json')
                snapshot[key] = value
                properties['source/snapshot.json'] = dumps(snapshot)
                with self.assertRaisesRegex(MuseumError, 'snapshot correspondence'):
                    join.reconcile(self.base, properties_files=properties)

    def test_properties_code_pin_and_block_are_observed_not_inherited(self):
        properties = property_observations(self.script)
        for mode in ('pin', 'block'):
            with self.subTest(mode=mode):
                changed = dict(properties)
                if mode == 'pin':
                    a = parsed(changed, 'source/anchor.json')
                    a['codePins'][0]['runtimeHash'] = schema_id('wrong runtime')
                    property_reseal(changed, anchor=a)
                else:
                    t = parsed(changed, 'source/transcript.json')
                    t['calls'][0]['params'][1]['blockHash'] = schema_id('wrong block')
                    property_reseal(changed, transcript=t)
                with self.assertRaisesRegex(MuseumError, 'runtime differs|observation block differs'):
                    join.reconcile(self.base, properties_files=changed)

    def test_aggregate_original_bounds_include_unavailable_rows_and_optional_bytes(self):
        missing = self.optional_call()
        del missing['result']
        missing['unavailable'] = {'kind': 'provider_error', 'code': -32000}
        self.append_script(missing)
        properties = property_observations(self.script)
        actual = join.reconcile(self.base, self.script, properties)['originalObservationCount']
        with mock.patch.object(join, 'MAX_SOURCE_ROWS', actual - 1):
            with self.assertRaisesRegex(MuseumError, 'original source row/count bound'):
                join.reconcile(self.base, self.script, properties)
        total = sum(len(raw) for files in (self.base, self.script, properties) for raw in files.values())
        with mock.patch.object(join, 'MAX_BYTES', total - 1):
            with self.assertRaisesRegex(MuseumError, 'aggregate input byte bound'):
                join.reconcile(self.base, self.script, properties)
        with mock.patch.object(join, 'MAX_SOURCES', 2):
            with self.assertRaisesRegex(MuseumError, 'original source row/count bound'):
                join.reconcile(self.base, self.script, properties)


if __name__ == '__main__':
    unittest.main()
