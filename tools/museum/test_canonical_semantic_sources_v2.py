"""Real all-family OwnerRecords source replays joined into unchanged V3 dossiers."""
from copy import deepcopy
from functools import lru_cache
import unittest
from unittest.mock import patch

from . import canonical_semantic_sources_v2 as sources
from . import acquisition_canonical_v10 as packet
from . import canonical_native_inputs_v1 as inputs
from . import owner_catalog_source as wire
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import encode
from .citations import canonical_citation
from .independent_wire import ZERO
from .title_v5_fixture import TitleV5Fixture, TOKEN, LATER_OWNER
from .test_acquisition_work_condition_v1 import title_case
from .test_acquisition_recovery_sustainability_v1 import RecoverySustainabilityFixture
from .test_acquisition_preservation_current_v1 import input_envelope
from .test_current_rights_source import H as _numeric_hash


SCHEMA_NAMES = sources.meaning.SCHEMA_NAMES


def H(value):
    return keccak256(value.encode('utf-8')) if type(value) is str else _numeric_hash(value)


def samples():
    from .test_condition import condition
    from .test_owner_exhibitions import owner_exhibition
    from .test_loans import loan
    from .test_valuations import valuation
    from .test_institutional import payload
    from tools.metadata.owner_notice_profile import examples
    notices = examples()
    return {**{family: payload(family) for family in ('ACCESSION', 'DEACCESSION', 'CITATION', 'REDEMPTION_CLAIM')},
        'CONDITION_REPORT': condition(), 'EXHIBITION': owner_exhibition(), 'LOAN': loan(), 'VALUATION': valuation(),
        'STEWARD_DESIGNATION': notices['steward-institution.json'],
        'RECOVERY_RESPONSE': notices['recovery-acknowledged.json']}


class AllFamilyOwnerFixture(TitleV5Fixture):
    """Every fixed lane plus one admitted future lane on the same original map."""
    def __init__(self, *, opaque=True):
        super().__init__()
        self.definition_plan = sources.plans.prepare()
        self.definitions_by_name = {d.name: d.content for d in self.definition_plan.documents}
        self.future_type = schema_id('FUTURE_OWNER_DOCUMENT')
        self.add(self.title_host, 'isOwnerRecordType(bytes32)', ('bytes32',), (self.future_type,), ('bool',), (True,))
        self.event(5, self.title_host, [wire.ADMISSION_EVENT, self.future_type, H('future admission')], ('uint16',), (1,))
        self.new_rows = {}
        examples = samples()
        for family in wire.FIXED_TYPES:
            if family in ('ACCESSION', 'DEACCESSION'): continue
            value = deepcopy(examples[family])
            if 'tokenId' in value: value['tokenId'] = str(TOKEN)
            if 'subjectId' in value: value['subjectId'] = subject_id('token', self.a['chainId'], self.core, '0', token_id=str(TOKEN))
            if 'subject' in value:
                value['subject'] = {'kind': 'token', 'collectionId': self.a['collectionId'], 'tokenId': str(TOKEN)}
            if 'workCitation' in value:
                value['workCitation'] = canonical_citation(self.a['chainId'], self.core, str(TOKEN),
                    {'kind': 'fin', 'hash': value['finality']['finalityHash']})
            if 'citedWork' in value:
                value['citedWork'] = canonical_citation(self.a['chainId'], self.core, str(TOKEN),
                    {'kind': 'chain', 'hash': H('cited original chain')})
            self.new_rows[family] = self.append_family(family, value)
        self.new_rows['OWNER_UNKNOWN'] = self.append_family('FUTURE_OWNER_DOCUMENT', {'future': 'uninterpreted statement'},
            schema_name='STREAM_FUTURE_OWNER_DOCUMENT_V1', schema_hash=H('unknown definition'))
        if opaque:
            # All are native-valid original records. Unsupported meanings must
            # survive beside supported rows, rather than vetoing extraction.
            wrong = deepcopy(examples['LOAN']); wrong['tokenId'] = '999'
            self.new_rows['foreign_payload'] = self.append_family('LOAN', wrong)
            self.new_rows['wrong_schema'] = self.append_family('VALUATION', deepcopy(examples['VALUATION']),
                schema_hash=H('different original valuation definition'))
            self.new_rows['wrong_canon'] = self.append_family('CITATION', deepcopy(examples['CITATION']),
                canon_hash=H('different original canon definition'))
            self.new_rows['non_json'] = self.append_family('EXHIBITION', b'{not JSON')
        self._title_lane_state()
        lane = [row for row in self.typed_rows if row[1][0] == self.future_type]
        self.add(self.title_host, 'recordChainHash(uint256,bytes32)', ('uint256', 'bytes32'),
            (TOKEN, self.future_type), ('bytes32', 'uint64'), (lane[-1][2][4], len(lane)))
        self.add(self.title_host, 'latestOwnerRecordHashFor(uint256,bytes32,address)',
            ('uint256', 'bytes32', 'address'), (TOKEN, self.future_type, LATER_OWNER), ('bytes32',), (lane[-1][0],))

    def append_family(self, family, value, *, schema_name=None, schema_hash=None, canon_hash=None):
        raw = value if type(value) is bytes else dumps(value)
        record_type = schema_id(family); name = schema_name or SCHEMA_NAMES[family]
        lane = [row for row in self.typed_rows if row[1][0] == record_type]
        record = (record_type, subject_id('token', self.a['chainId'], self.core, '0', token_id=str(TOKEN)),
            schema_id(name), (1, hex_bytes(keccak256(raw)), schema_id('RFC8785_JCS')),
            'ipfs://synthetic-owner-family/' + str(len(self.typed_rows)), raw, 1)
        stamp = int(self.blocks[H(205)]['timestamp'], 16)
        bundle = encode(('bytes32', 'address', 'bytes32'), (schema_id('DIRECT'), LATER_OWNER, keccak256(raw)))
        receipt = [TOKEN, LATER_OWNER, stamp, len(lane), ZERO, False, ZERO, 0, 0,
            schema_hash or keccak256(self.definitions_by_name[name]),
            canon_hash or keccak256(self.definitions_by_name['RFC8785_JCS']), schema_id('DIRECT'), keccak256(bundle)]
        digest = wire.native_hash(int(self.a['chainId']), self.title_host, self.core, record, receipt)
        receipt[4] = record_chain(self.a['chainId'], self.title_host, str(TOKEN), record_type,
            lane[-1][2][4] if lane else ZERO, digest, str(receipt[3]))
        receipt = tuple(receipt); self.typed_rows.append((digest, record, receipt, bundle))
        pointer = self._carrier(bundle)
        self.add(self.title_host, 'ownerRecord(bytes32)', ('bytes32',), (digest,), (wire.OWNER_RECORD, wire.RECEIPT), (record, receipt))
        self.add(self.title_host, 'ownerRecordSignatureBundle(bytes32)', ('bytes32',), (digest,), ('address', 'bytes'), (pointer, bundle))
        self.add(self.title_host, 'recordHashAt(uint256,bytes32,uint256)', ('uint256', 'bytes32', 'uint256'),
            (TOKEN, record_type, receipt[3]), ('bytes32',), (digest,))
        self.owner_events[digest] = self.event(5, self.title_host,
            [wire.RECORD_EVENT, self.topic('uint256', TOKEN), record_type, self.topic('address', LATER_OWNER)],
            (wire.OWNER_RECORD, 'bytes32', 'bytes32', 'bool', 'uint16'), (record, digest, receipt[4], False, 1))
        return digest


@lru_cache(maxsize=1)
def complete_case():
    """Full concrete V10/V3 composition, all original source maps agree."""
    base = AllFamilyOwnerFixture()
    state = {key: str(TOKEN) if key == 'tokenId' else base.a[key] for key in packet.observations.STATE_KEYS}
    recovery = RecoverySustainabilityFixture(source_state=state, base=base, mode='empty')
    prior, evidence, kwargs = title_case(base)
    _, preservation = input_envelope(state, source_header=deepcopy(base.blocks[state['blockHash']]))
    native, native_hash = inputs.create(dumps(preservation), dumps(evidence), kwargs['metadata_files'],
        recovery.envelope(), condition_files=kwargs['condition_files'])
    v10 = packet.compose(prior.files, prior.manifest_hash, native, native_hash, disclosure='public')
    return sources.dossier.compose(v10.files, v10.manifest_hash, disclosure='public')


class CanonicalSemanticSourcesV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = sources.plans.prepare()
        cls.result = complete_case(); cls.files = dict(cls.result.files)
        with patch('socket.socket', side_effect=AssertionError('network used')):
            cls.checked, cls.inventory = sources.admit(cls.files, cls.result.manifest_hash,
                plan_files=dict(cls.plan.files), plan_hash=cls.plan.manifest_hash)

    def owners(self): return [row for row in self.inventory['rows'] if row['ownerMeaning'] is not None]

    def test_all_ten_plus_future_and_complete_original_denominator(self):
        original = loads(self.files[sources.OWNER_PREFIX + 'sources/owner/snapshot.json'], maximum=sources.dossier.MAX_BYTES)
        rows = self.owners()
        self.assertEqual(len(rows), len(original['records']))
        self.assertEqual([r['original'] for r in rows], original['records'])
        self.assertTrue(set(wire.FIXED_TYPES) <= {r['family'] for r in rows})
        self.assertTrue(set(wire.FIXED_TYPES) <= {r['family'] for r in rows if r['semantic'] is not None})
        self.assertTrue(any(r['family'] == 'OWNER_UNKNOWN' and r['semantic'] is None for r in rows))
        self.assertEqual(self.inventory['denominators']['owner']['lanes'], original['lanes'])
        self.assertEqual(self.inventory['denominators']['owner']['historyCoverage'], original['historyCoverage'])

    def test_original_authorities_and_selected_accession_remain_distinct(self):
        selected = [r for r in self.owners() if r['currentness']['selected']]
        self.assertEqual(len(selected), 1); self.assertEqual(selected[0]['family'], 'ACCESSION')
        for row in self.owners():
            self.assertEqual(row['authority']['mode'], 'historical_native_owner_receipt')
            self.assertNotIn('authorityClass', row['authority'])
            if row not in selected: self.assertEqual(row['currentness']['status'], 'historical_original')
        self.assertFalse(self.inventory['claims']['nativeOwnerSpecializedStateProven'])

    def test_opaque_schema_canon_and_payload_subject_do_not_drop_rows(self):
        opaque = [r for r in self.owners() if r['semantic'] is None]
        self.assertGreaterEqual(len(opaque), 6)
        self.assertTrue(all(r['ownerMeaning']['reason'] for r in opaque))
        self.assertTrue(any(b'999' in sources.resolve_reference(self.files, r['pointers']['payload']) for r in opaque))
        self.assertTrue(any(b'{not JSON' == sources.resolve_reference(self.files, r['pointers']['payload']) for r in opaque))

    def test_all_pointers_resolve_and_v2_ids_cover_every_leaf(self):
        for row in self.inventory['rows']:
            for reference in row['pointers'].values():
                if reference is not None: sources.resolve_reference(self.files, reference)
            identity = {'profileHash': sources.PROFILE_HASH, 'sourceManifestHash': self.result.manifest_hash,
                'selector': row['selector'], 'originalPointer': row['pointers']['original']}
            self.assertEqual(row['occurrenceId'], keccak256(dumps(identity)))
        self.assertEqual(self.inventory['leaves'], sources.field_inventory(self.inventory['rows']))
        self.assertTrue(all(row['ownerMeaning'] is None for row in self.inventory['rows']
            if row['selector']['kind'] != 'native_owner_family'))

    def test_explicit_retained_plan_never_reads_current_definition_tree(self):
        with patch.object(sources.plans, 'prepare', side_effect=AssertionError('unexpected current file read')):
            definitions = sources.definition_files(plan_files=dict(self.plan.files), plan_hash=self.plan.manifest_hash)
            inventory = sources._extract(self.files, self.result.manifest_hash,
                plan_files=dict(self.plan.files), plan_hash=self.plan.manifest_hash)
        self.assertEqual(inventory, self.inventory)
        self.assertEqual(len(inventory['ownerDefinitions']['documents']), 51)
        self.assertEqual(definitions['definitions/owner-genesis-plan/manifest.json'], self.plan.manifest)
        self.assertEqual(definitions['definitions/owner-family-profile.json'], sources.meaning.PROFILE_BYTES)
        self.assertEqual(inventory['ownerDefinitions']['pathBase'], 'export')
        self.assertFalse(inventory['ownerDefinitions']['registrationObserved'])

    def test_plan_pin_pair_and_rehashed_definition_changes_reject(self):
        with self.assertRaises(MuseumError): sources.definition_files(plan_files=dict(self.plan.files))
        altered = dict(self.plan.files)
        path = next(p for p in altered if p.startswith('definitions/'))
        altered[path] += b' '
        with self.assertRaises(MuseumError): sources.definition_files(plan_files=altered, plan_hash=self.plan.manifest_hash)

    def test_structural_owner_hash_and_lane_corruption_reject(self):
        path = sources.OWNER_PREFIX + 'sources/owner/snapshot.json'
        for edit in (lambda v: v['records'][0].update(recordHash=H('forged')),
                     lambda v: v['records'].append(deepcopy(v['records'][0])),
                     lambda v: v['lanes'][0].update(count='999')):
            files = dict(self.files); snapshot = loads(files[path], maximum=sources.dossier.MAX_BYTES); edit(snapshot)
            files[path] = dumps(snapshot)
            with self.assertRaises(MuseumError): sources._owner(sources.previous._SourceFiles(files),
                self.inventory['sourceState'], self.result.manifest_hash, self.plan)

    def test_original_nineteen_and_forty_nine_inputs_remain_unchanged(self):
        self.assertEqual(self.checked.files, self.result.files)
        original = loads(self.files[sources.dossier.DOSSIER_PATH], maximum=sources.dossier.MAX_BYTES)
        self.assertEqual(self.inventory['finality'], original['acquisitionPacket']['finality'])
        self.assertEqual(self.inventory['recordHeads'], original['originalRecordChainHeads'])
        requirements = loads(self.files['dossier/requirements.json'], maximum=sources.dossier.MAX_BYTES)
        self.assertEqual(requirements['counts']['total'], 49)
        self.assertFalse(self.inventory['claims']['globalHostUniverseProven'])


if __name__ == '__main__': unittest.main()
