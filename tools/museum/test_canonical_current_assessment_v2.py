"""Current token-script requirement joins replay originals at one target/state."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import canonical_current_assessment_v2 as current
from . import canonical_dossier_script_links_fixture_v1 as shared_script
from . import token_script_interpretation_v1 as interpretation
from . import token_script_capture_v1 as token_capture
from . import token_script_registered_capture_v1 as registered_capture
from . import token_script_source_v1 as token_source
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import DOCUMENT_SPEC, RAW_BYTES, ZERO
from .publication import KINDS
from . import test_canonical_current_assessment_v1 as previous_tests
from .test_token_script_source_v1 import TokenScriptFixture
from .test_current_rights_source import A, H
from .test_preservation_resources import RightsFixture
from .test_public_personhood_source import PublicPersonhoodMixin


class CurrentScriptAssessmentTests(unittest.TestCase):
    @staticmethod
    def exact_jcs_facts():
        # The older rights fixture used a placeholder native declaration for
        # identical JCS bytes. Correct it before dependent summaries are made.
        jcs = interpretation.documents()[0]
        chunks = tuple(jcs.content[start:start + 8192]
            for start in range(0, len(jcs.content), 8192))
        hashes = tuple(keccak256(chunk) for chunk in chunks)
        spec = (jcs.name, KINDS[jcs.kind], keccak256(jcs.content),
            jcs.canonicalization_id, jcs.supersedes_id, jcs.uri,
            len(jcs.content))
        declaration = keccak256(encode((DOCUMENT_SPEC, Array('bytes32')),
            (spec, hashes)))
        facts = (True, KINDS[jcs.kind], 0, spec[2], RAW_BYTES, ZERO,
            len(jcs.content), len(hashes), declaration)
        return facts

    @staticmethod
    def fixture_hook(base):
        for role in ('COLLECTION_METADATA', 'METADATA_ROUTER'):
            shared_script._upgrade_pointer(base, role)
        state = dict(base.scoped_policy_context)
        addresses = base.scoped_policy_addresses
        context = {'chainId': state['chainId'], 'core': state['core'],
            'collectionId': state['collectionId'], 'metadata': base.a['host'],
            'router': addresses['router'], 'store': addresses['store'],
            'moduleRegistry': base.configuration[0][6]}
        shared = (state['core'], base.a['host'], addresses['router'],
            addresses['store'], A(8), A(10), context['moduleRegistry'],
            addresses['schemas'], A(12))
        runtimes = {address: base.codes[address] for address in shared
            if address in base.codes}
        script = TokenScriptFixture('stable', frozen=False,
            context_overrides=context, source_state=state,
            runtime_overrides=runtimes, history_offset=-8)
        receipt = base.receipts[H(400)]
        for log in (item for original in sorted(script.history_receipts.values(),
                key=lambda row: int(row['blockNumber'], 16))
                for item in original['logs']):
            log.update({key: receipt[key] for key in
                ('transactionHash', 'blockHash', 'blockNumber', 'transactionIndex')})
            log['logIndex'] = hex(len(receipt['logs']))
            receipt['logs'].append(log)

    @classmethod
    def setUpClass(cls):
        previous_tests.CurrentAssessmentTests.fixture_hook = cls.fixture_hook
        original_add = RightsFixture.add
        original_definition = PublicPersonhoodMixin._definition
        jcs_facts = cls.exact_jcs_facts()
        jcs_id = schema_id(interpretation.documents()[0].name)
        def add_exact_jcs(base, target, signature, kinds, values, outputs, result):
            if (target == A(3) and signature == 'documentFacts(bytes32)' and
                    values == (jcs_id,)):
                result = (jcs_facts,)
            return original_add(base, target, signature, kinds, values, outputs, result)
        def define_exact_jcs(base, name, kind, raw):
            result = original_definition(base, name, kind, raw)
            if name != 'RFC8785_JCS':
                return result
            frozen = (jcs_facts[0], jcs_facts[1], *jcs_facts[3:])
            kinds = ('bool', 'uint8', 'bytes32', 'bytes32', 'bytes32',
                'uint32', 'uint256', 'bytes32')
            return keccak256(encode(kinds, frozen)), result[1]
        try:
            with patch.object(RightsFixture, 'add', add_exact_jcs), \
                    patch.object(PublicPersonhoodMixin, '_definition', define_exact_jcs):
                previous_tests.CurrentAssessmentTests.setUpClass()
        finally:
            del previous_tests.CurrentAssessmentTests.fixture_hook
        cls.previous = previous_tests.CurrentAssessmentTests.all_five
        cls.base_fixture = previous_tests.CurrentAssessmentTests.fixture
        cls.script = cls.registered('stable')
        cls.result = current.compose(dict(cls.previous.files), cls.previous.manifest_hash,
            script_files=dict(cls.script.files), script_hash=cls.script.manifest_hash,
            disclosure='public')

    @classmethod
    def registered(cls, mode, *, state_override=None, incomplete_dependency=False,
            pointer_conflict=None, carrier_conflict=False):
        source_state = dict(cls.previous.report['sourceState'])
        if state_override: source_state.update(state_override)
        original = cls.base_fixture
        addresses = original.scoped_policy_addresses
        context = {'chainId': source_state['chainId'], 'core': source_state['core'],
            'collectionId': source_state['collectionId'], 'metadata': original.a['host'],
            'router': addresses['router'], 'store': addresses['store'],
            'moduleRegistry': original.configuration[0][6]}
        shared = (source_state['core'], original.a['host'], addresses['router'],
            addresses['store'], A(8), A(10), context['moduleRegistry'],
            addresses['schemas'], A(12))
        runtimes = {address: original.codes[address] for address in shared
            if address in original.codes}
        fixture = TokenScriptFixture(mode, frozen=False, context_overrides=context,
            source_state=source_state, runtime_overrides=runtimes,
            history_offset=-8)
        pointer_raw = {}
        for role in ('COLLECTION_METADATA', 'METADATA_ROUTER'):
            data = calldata('getSatellitePointer(bytes32)', ('bytes32',),
                (schema_id(role),))
            raw = original.responses[(fixture.core, data)]
            if pointer_conflict == role:
                pointer = list(decode((shared_script.script_source.POINTER,),
                    hex_bytes(raw))[0])
                pointer[7] = keccak256(('contradictory ' + role).encode())
                raw = '0x' + encode((shared_script.script_source.POINTER,),
                    (tuple(pointer),)).hex()
            pointer_raw[role] = raw
            fixture.put('eth_call', [{'to': fixture.core, 'data': data,
                'gas': '0x1312d00'}, fixture.block_ref], raw)
        # Both readers replay the exact receipt augmented before V1 capture.
        historical = [log for receipt in sorted(fixture.history_receipts.values(),
            key=lambda row: int(row['blockNumber'], 16)) for log in receipt['logs']]
        header = deepcopy(original.blocks[H(200)])
        receipt = deepcopy(original.receipts[H(400)])
        signatures = (token_source.AUTHORIZATION_EVENT,
            token_source.RECORDED_EVENT, token_source.ACTIVATED_EVENT)
        shared_logs = [log for log in receipt['logs'] if log['address'] == fixture.router
            and log['topics'][0] in signatures]
        # Record hashes are independent of manifest availability when STATIC
        # source freezing is disabled in this shared fixture.
        assert [(row['topics'], row['data']) for row in shared_logs] == [
            (row['topics'], row['data']) for row in historical]
        fixture.history_headers = {header['hash']: header}
        fixture.history_receipts = {receipt['transactionHash']: receipt}
        if source_state['blockHash'] == original.blocks[H(205)]['hash']:
            fixture.block = deepcopy(original.blocks[H(205)])
            fixture.put('eth_getBlockByHash', [fixture.block['hash'], False], fixture.block)
            fixture.put('eth_getBlockByNumber', [fixture.block['number'], False], fixture.block)
        if incomplete_dependency:
            fixture.fail(fixture.metadata, 'dependencyChunk(bytes32,uint256)',
                ('bytes32', 'uint256'), (fixture.value['library']['bundleId'], 0))
        token = fixture.source(); token.snapshot(); transcript = token.transcript()
        child = token_capture.replay(fixture.anchor_raw,
            keccak256(fixture.anchor_raw), transcript, keccak256(transcript),
            fixture.runtime_bridge_raw, keccak256(fixture.runtime_bridge_raw),
            provenance='synthetic_fixture', disclosure='public')
        metadata_pointer = decode((shared_script.script_source.POINTER,),
            hex_bytes(pointer_raw['COLLECTION_METADATA']))[0]
        jcs_digest = keccak256(interpretation.documents()[0].content)
        chunk_data = calldata('chunk(bytes32)', ('bytes32',), (jcs_digest,))
        carrier = decode((('address', 'uint32'),),
            hex_bytes(original.responses[(addresses['store'], chunk_data)]))[0]
        registry = fixture.install_registry(schemas_address=addresses['schemas'],
            runtime_overrides=runtimes, metadata_pointer=metadata_pointer,
            carrier_overrides={} if carrier_conflict else
                {jcs_digest: (carrier[0], original.codes[carrier[0]])})
        registry.snapshot()
        registry_transcript = registry.transcript()
        return registered_capture.compose(dict(child.files), child.manifest_hash,
            fixture.registry_anchor_raw, keccak256(fixture.registry_anchor_raw),
            registry_transcript, keccak256(registry_transcript), disclosure='public')

    def test_exact_registered_script_advances_only_one_of_forty_nine_rows(self):
        files = dict(self.result.files)
        assessment = loads(files[current.ASSESSMENT_PATH], maximum=current.MAX_BYTES)
        self.assertEqual(assessment['workClass'], 'script')
        self.assertEqual(assessment['counts']['total'], 49)
        self.assertEqual(assessment['counts']['verified'], 6)
        self.assertEqual(self.result.report['currentVerifiedCodes'],
            ['identity', 'OD-FINALITY-STATUS', 'OD-CONTENT-ROOT-PROOF',
            'OD-ENTROPY-PROVENANCE', 'OD-SCRIPT-MANIFEST', 'OD-ATTRIBUTION'])
        rows = {row['code']: row for row in assessment['results']}
        self.assertEqual(rows['OD-SCRIPT-MANIFEST']['state'], 'verified')
        self.assertEqual(rows['OD-DEPENDENCY-MANIFEST']['state'], 'missing')
        self.assertFalse(self.result.report['complete'])
        for path, body in self.previous.files:
            self.assertEqual(files['current-v1/' + path], body)
        for path, body in self.script.files:
            self.assertEqual(files['script/' + path], body)
        with patch('socket.socket', side_effect=AssertionError('verify used network')):
            self.assertEqual(current.verify(files, self.result.manifest_hash).manifest_hash,
                self.result.manifest_hash)

    def test_unknown_and_incomplete_dependency_stay_unresolved(self):
        for mode, incomplete, expected_work in (('empty', False, 'unknown'),
                ('chunked', True, 'script')):
            with self.subTest(mode=mode):
                child = self.registered(mode, incomplete_dependency=incomplete)
                joined = current.compose(dict(self.previous.files),
                    self.previous.manifest_hash, script_files=dict(child.files),
                    script_hash=child.manifest_hash, disclosure='public')
                assessment = loads(dict(joined.files)[current.ASSESSMENT_PATH],
                    maximum=current.MAX_BYTES)
                row = next(row for row in assessment['results']
                    if row['code'] == current.SCRIPT_CODE)
                self.assertEqual(assessment['workClass'], expected_work)
                self.assertNotEqual(row['state'], 'verified')
                self.assertEqual(assessment['counts']['verified'], 5)
                self.assertEqual(current.verify(dict(joined.files),
                    joined.manifest_hash).manifest_hash, joined.manifest_hash)

    def test_mixed_target_and_rehashed_script_tamper_reject(self):
        source = self.previous.report['sourceState']
        for key, value in (('tokenId', '42'), ('blockHash', '0x' + '88' * 32),
                ('collectionId', '2'), ('core', '0x' + '99' * 20)):
            with self.subTest(key=key), self.assertRaises(MuseumError):
                current._script_refs(dict(self.script.files),
                    dict(source, **{key: value}), dict(self.previous.files))
        different = self.registered('stable',
            state_override={'blockHash': '0x' + '88' * 32})
        with self.assertRaisesRegex(MuseumError, 'exact token/source state'):
            current.compose(dict(self.previous.files), self.previous.manifest_hash,
                script_files=dict(different.files), script_hash=different.manifest_hash,
                disclosure='public')
        damaged = dict(self.script.files)
        damaged['token/payloads/script.bin'] += b'changed'
        manifest = loads(damaged['manifest.json'], maximum=current.MAX_MANIFEST)
        manifest['files'] = [current.package._ref(path, raw)
            for path, raw in sorted(damaged.items()) if path != 'manifest.json']
        damaged['manifest.json'] = dumps(manifest)
        with self.assertRaises(MuseumError):
            current.compose(dict(self.previous.files), self.previous.manifest_hash,
                script_files=damaged, script_hash=keccak256(damaged['manifest.json']),
                disclosure='public')

    def test_rehashed_same_anchor_pointer_and_store_conflicts_reject(self):
        for role in ('COLLECTION_METADATA', 'METADATA_ROUTER'):
            with self.subTest(role=role):
                child = self.registered('stable', pointer_conflict=role)
                self.assertEqual(registered_capture.verify(dict(child.files),
                    child.manifest_hash).manifest_hash, child.manifest_hash)
                with self.assertRaisesRegex(MuseumError,
                        'overlapping positive read differs'):
                    current.compose(dict(self.previous.files), self.previous.manifest_hash,
                        script_files=dict(child.files), script_hash=child.manifest_hash,
                        disclosure='public')
        child = self.registered('stable', carrier_conflict=True)
        self.assertEqual(registered_capture.verify(dict(child.files),
            child.manifest_hash).manifest_hash, child.manifest_hash)
        with self.assertRaisesRegex(MuseumError, 'overlapping positive read differs'):
            current.compose(dict(self.previous.files), self.previous.manifest_hash,
                script_files=dict(child.files), script_hash=child.manifest_hash,
                disclosure='public')


if __name__ == '__main__': unittest.main()
