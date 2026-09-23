"""Current native-state requirement references are earned from replayed proofs."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import canonical_current_assessment_v1 as current
from . import canonical_object_dossier_v4 as v4
from . import public_mint_entropy_capture as entropy
from . import public_scoped_policy_finality_capture_v2 as finality
from . import test_canonical_semantic_sources_v2 as source_case
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .canonical_object_dossier_fixture_v4 import canonical_case, complete_case_v4
from .mint_entropy_source import (CONFIG, COORDINATOR_INTERFACE, ENTROPY_REGISTERED,
    FINALIZED, MODULE_TYPE, POLICY, RECOVERY, REQUEST, REQUESTED, SUBJECT,
    TOKEN_ENTROPY, TRANSFER, VIEW_INTERFACE, request_hash, seed_hash, token_key)
from .public_mint_entropy_source import PublicMintEntropySource, PROFILE as ENTROPY_PROFILE
from .scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2
from .test_public_mint_entropy_source import PublicMintEntropyFixture
from .test_mint_entropy_source import A, H, ZERO
from .title_v5_fixture import TOKEN, COLLECTION


def repin(files):
    manifest = loads(files['manifest.json'], maximum=current.MAX_MANIFEST)
    manifest['files'] = [current.package._ref(path, raw) for path, raw in sorted(files.items())
        if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class TerminalEntropySourceMixin:
    """Add one exact-state synthetic entropy lane to the existing V4 RPC map."""

    def event(self, block, address, topics, kinds, values):
        if (address == getattr(self, 'core', None) and topics[0] == TRANSFER and
                topics[1] == ZERO and topics[3] == H(TOKEN)):
            super().event(block, self.entropy_coordinator,
                [ENTROPY_REGISTERED, H(COLLECTION), H(TOKEN)],
                ('bytes32',), (self.entropy_commitment,))
            self.entropy_registered_block = block
        return super().event(block, address, topics, kinds, values)

    def reorder_logs(self, block, logs):
        # The DIRECT fixture moves its mint Transfer from block 4 into the
        # paid transaction before title captures begin. Move the matching
        # registration with it while the shared source map is still mutable.
        if (block != 4 and any(log['address'] == getattr(self, 'core', None)
                and log['topics'][0] == TRANSFER and log['topics'][1] == ZERO
                and log['topics'][3] == H(TOKEN) for log in logs)):
            old = self.receipts[H(404)]
            registrations = [log for log in old['logs'] if
                log['address'] == self.entropy_coordinator and
                log['topics'][0] == ENTROPY_REGISTERED]
            if registrations:
                registration, = registrations
                old['logs'].remove(registration)
                destination = self.receipts[H(400 + block)]
                registration.update({key: destination[key] for key in
                    ('transactionHash', 'blockHash', 'blockNumber', 'transactionIndex')})
                index = next(i for i, log in enumerate(logs) if
                    log['address'] == self.core and log['topics'][0] == TRANSFER
                    and log['topics'][1] == ZERO and log['topics'][3] == H(TOKEN))
                logs.insert(index, registration)
                self.entropy_registered_block = block
        return super().reorder_logs(block, logs)

    def install_terminal_entropy(self):
        host, token, cid = self.entropy_coordinator, TOKEN, COLLECTION
        self.codes[host] = b'synthetic current-assessment entropy coordinator'
        self.pins[host] = keccak256(self.codes[host])
        for interface, value in (('0x01ffc9a7', True),
                (COORDINATOR_INTERFACE, True), (VIEW_INTERFACE, True),
                ('0xffffffff', False)):
            self.add(host, 'supportsInterface(bytes4)', ('bytes4',), (interface,), ('bool',), (value,))
        for signature, outputs, values in (
                ('core()', ('address',), (self.core,)),
                ('streamModuleType()', ('bytes32',), (MODULE_TYPE,)),
                ('streamModuleVersion()', ('bytes32',),
                    (schema_id('6529stream.entropy-coordinator.v1'),)),
                ('streamModuleInterfaceId()', ('bytes4',), (COORDINATOR_INTERFACE,))):
            self.add(host, signature, (), (), outputs, values)
        self.add(self.core, 'coordinatorAtMint(uint256)', ('uint256',), (token,), ('address',), (host,))
        data = b'synthetic shared token data'
        self.add(self.core, 'tokenData(uint256)', ('uint256',), (token,), ('bytes',), (data,))
        anchor = {key: self.a[key] for key in ('chainId', 'core', 'blockHash', 'blockNumber',
            'timestamp', 'stateRoot', 'environment', 'deploymentEvidenceHash')}
        self.entropy_anchor = {**anchor, 'profile': ENTROPY_PROFILE, 'tokenId': str(token),
            'collectionId': str(cid), 'coordinator': host, 'codePins': [
                {'address': address, 'runtimeHash': self.pins[address]}
                for address in (self.core, host)]}
        config = (A(30), True, True, 100, H(501), H(503), H(503))
        policy = (config[0], config[5], 1, config[4], config[6], self.entropy_commitment, 1)
        key = request_hash(self.entropy_anchor, policy)
        request = (token_key(token), token, ZERO, policy[0], 5, 41, H(700))
        seed = seed_hash(self.entropy_anchor, key, request, policy, request[-1])
        self.event(5, host, [REQUESTED, key, H(token), ZERO],
            ('address', 'uint256'), (policy[0], request[5]))
        self.event(5, host, [FINALIZED, key, H(token), ZERO],
            ('bytes32', 'bytes32'), (seed, request[-1]))
        for signature, inputs, args, outputs, result in (
                ('collectionEntropyConfig(uint256)', ('uint256',), (cid,), CONFIG, config),
                ('collectionProviderEpoch(uint256)', ('uint256',), (cid,), ('uint32',), (1,)),
                ('tokenEntropy(uint256)', ('uint256',), (token,), TOKEN_ENTROPY,
                    (5, seed, policy[0], policy[2], policy[3], key, request[5], policy[6])),
                ('tokenEntropyStatus(uint256)', ('uint256',), (token,), ('uint8',), (5,)),
                ('tokenSeed(uint256)', ('uint256',), (token,), ('bytes32', 'bool'), (seed, True)),
                ('scopeEntropy(bytes32)', ('bytes32',), (token_key(token),), SUBJECT,
                    (cid, self.entropy_commitment, key, seed, 5)),
                ('registeredAtBlock(uint256)', ('uint256',), (token,), ('uint64',),
                    (self.entropy_registered_block,)),
                ('requests(bytes32)', ('bytes32',), (key,), REQUEST, request),
                ('requestPolicySnapshot(bytes32)', ('bytes32',), (key,), POLICY, policy),
                ('providerRequestKeys(address,uint256)', ('address', 'uint256'),
                    (policy[0], request[5]), ('bytes32',), (key,)),
                ('freshRecoveryReceipt(bytes32)', ('bytes32',), (key,), RECOVERY,
                    (ZERO,) * 7 + (0, False))):
            self.add(host, signature, inputs, args, outputs, result)

    def request(self, method, params):
        if method == 'eth_getLogs':
            self.requested.append((method, deepcopy(params)))
            rows = [deepcopy(log) for receipt in self.receipts.values()
                for log in receipt['logs'] if PublicMintEntropyFixture.matches(log, params[0])]
            return sorted(rows, key=lambda log: (int(log['blockNumber'], 16),
                int(log['transactionIndex'], 16), int(log['logIndex'], 16)))
        if method == 'eth_getBlockByNumber':
            self.requested.append((method, deepcopy(params)))
            rows = [block for block in self.blocks.values() if block['number'] == params[0]]
            assert len(rows) == 1 and params[1] is False
            return deepcopy(rows[0])
        return super().request(method, params)

    def entropy_source(self):
        return PublicMintEntropySource(dumps(self.entropy_anchor), self)


class CurrentAssessmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        holder = {}

        class CoherentFixture(TerminalEntropySourceMixin, source_case.AllFamilyOwnerFixture,
                ScopedPolicyFinalityFixtureV2):
            def __init__(self):
                self.entropy_coordinator = A(200000)
                self.entropy_commitment = H(600)
                super().__init__()
                self.install_terminal_entropy()
                holder['fixture'] = self

        with patch.object(source_case, 'AllFamilyOwnerFixture', CoherentFixture), \
                patch('socket.socket', side_effect=AssertionError('fixture used network')):
            source_case.complete_case.cache_clear(); canonical_case.cache_clear()
            original = canonical_case()
            cls.base = v4.compose(dict(original.files), original.manifest_hash, disclosure='public')
            fixture = holder['fixture']; adapter = fixture.policy_source(); adapter.snapshot()
            transcript = adapter.transcript()
            cls.finality = finality.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
                finality._source().PROFILE_HASH, transcript, keccak256(transcript),
                provenance='synthetic_fixture', disclosure='public')
            adapter = fixture.entropy_source(); adapter.snapshot(); transcript = adapter.transcript()
            cls.joined_entropy = entropy.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
                entropy._source().PROFILE_HASH, transcript, keccak256(transcript),
                provenance='synthetic_fixture', disclosure='public')
            entropy_fixture = PublicMintEntropyFixture(source_block=6, recovery=True, late=True)
            adapter = entropy_fixture.source(); adapter.snapshot(); transcript = adapter.transcript()
            cls.entropy = entropy.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
                entropy._source().PROFILE_HASH, transcript, keccak256(transcript),
                provenance='synthetic_fixture', disclosure='public')
            cls.result = current.compose(dict(cls.base.files), cls.base.manifest_hash,
                finality_files=dict(cls.finality.files), finality_hash=cls.finality.manifest_hash,
                disclosure='public')
            cls.all_five = current.compose(dict(cls.base.files), cls.base.manifest_hash,
                finality_files=dict(cls.finality.files), finality_hash=cls.finality.manifest_hash,
                entropy_files=dict(cls.joined_entropy.files),
                entropy_hash=cls.joined_entropy.manifest_hash, disclosure='public')
        source_case.complete_case.cache_clear(); canonical_case.cache_clear()

    def test_four_exact_native_codes_and_original_denominators(self):
        files = dict(self.result.files)
        assessment = loads(files[current.ASSESSMENT_PATH], maximum=current.MAX_BYTES)
        self.assertEqual(self.result.report['currentVerifiedCodes'],
            ['identity', 'OD-FINALITY-STATUS', 'OD-CONTENT-ROOT-PROOF', 'OD-ATTRIBUTION'])
        self.assertEqual(assessment['counts']['total'], 49)
        self.assertEqual(assessment['workClass'], 'unknown')
        self.assertFalse(assessment['complete'])
        self.assertEqual(self.result.report['originalPacketGroupCount'], '19')
        self.assertEqual(self.result.report['originalRequirementCount'], '49')
        for path, raw in self.base.files:
            self.assertEqual(files['v4/' + path], raw)
        old = loads(dict(self.base.files)['canonical/input/dossier/requirements.json'],
            maximum=current.MAX_BYTES)
        self.assertEqual(old['counts']['verified'], 1)
        self.assertEqual(assessment['counts']['verified'], 4)
        self.assertFalse(self.result.report['claims']['chainConsensusProven'])
        with patch('socket.socket', side_effect=AssertionError('verify used network')):
            self.assertEqual(current.verify(files, self.result.manifest_hash).manifest_hash,
                self.result.manifest_hash)

    def test_all_five_exact_native_codes_join_from_one_synthetic_source_map(self):
        files = dict(self.all_five.files)
        assessment = loads(files[current.ASSESSMENT_PATH], maximum=current.MAX_BYTES)
        self.assertEqual(self.all_five.report['currentVerifiedCodes'], [
            'identity', 'OD-FINALITY-STATUS', 'OD-CONTENT-ROOT-PROOF',
            'OD-ENTROPY-PROVENANCE', 'OD-ATTRIBUTION'])
        self.assertEqual(assessment['counts']['total'], 49)
        self.assertEqual(assessment['counts']['verified'], 5)
        self.assertFalse(assessment['complete'])
        self.assertEqual(self.all_five.report['originalPacketGroupCount'], '19')
        self.assertEqual(self.all_five.report['originalRequirementCount'], '49')
        for path, raw in self.base.files:
            self.assertEqual(files['v4/' + path], raw)
        with patch('socket.socket', side_effect=AssertionError('verify used network')):
            self.assertEqual(current.verify(files, self.all_five.manifest_hash).manifest_hash,
                self.all_five.manifest_hash)

    def test_entropy_proof_is_typed_and_only_exact_target_can_join(self):
        files = dict(self.entropy.files)
        anchor = loads(files['source/anchor.json'], maximum=current.MAX_BYTES)
        source = {key: anchor[key] for key in current.STATE_KEYS}
        refs = current._entropy_refs(files, source)
        self.assertEqual(set(refs), {'OD-ENTROPY-PROVENANCE'})
        self.assertEqual(len(refs['OD-ENTROPY-PROVENANCE']), 2)
        for field, value in (('tokenId', '72'), ('blockHash', '0x' + '33' * 32),
                             ('collectionId', '7')):
            changed = dict(source, **{field: value})
            with self.subTest(field=field), self.assertRaises(MuseumError):
                current._entropy_refs(files, changed)
        registered = PublicMintEntropyFixture(source_block=6, status=3)
        adapter = registered.source(); adapter.snapshot(); transcript = adapter.transcript()
        incomplete = entropy.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
            entropy._source().PROFILE_HASH, transcript, keccak256(transcript),
            provenance='synthetic_fixture', disclosure='public')
        incomplete_files = dict(incomplete.files)
        incomplete_anchor = loads(incomplete_files['source/anchor.json'], maximum=current.MAX_BYTES)
        self.assertEqual(current._entropy_refs(incomplete_files,
            {key: incomplete_anchor[key] for key in current.STATE_KEYS}), {})
        with self.assertRaisesRegex(MuseumError, 'exact native source state'):
            current.compose(dict(self.base.files), self.base.manifest_hash,
                entropy_files=files, entropy_hash=self.entropy.manifest_hash,
                disclosure='public')

    def test_wrong_finality_token_or_block_rejects(self):
        files = dict(self.finality.files)
        base = dict(self.base.files)
        source, packet, *_ = current._native_context(base, self.base.report)
        for field, value in (('tokenId', '42'), ('blockHash', '0x' + '33' * 32)):
            with self.subTest(field=field), self.assertRaises(MuseumError):
                current._finality_refs(files, dict(source, **{field: value}), packet)

    def test_truncated_proof_and_rehashed_native_tamper_reject(self):
        final_files = dict(self.finality.files)
        proof = loads(final_files['scoped-policy-finality/token-proof.json'], maximum=current.MAX_BYTES)
        proof['leaf'] = proof['leaf'][:-1]
        final_files['scoped-policy-finality/token-proof.json'] = dumps(proof)
        with self.assertRaises(MuseumError): finality.verify(final_files, repin(final_files))
        entropy_files = dict(self.entropy.files)
        fragment = loads(entropy_files['entropy/packet-fragment.json'], maximum=current.MAX_BYTES)
        fragment['leaf']['provider'] = '0x' + '55' * 20
        entropy_files['entropy/packet-fragment.json'] = dumps(fragment)
        with self.assertRaises(MuseumError): entropy.verify(entropy_files, repin(entropy_files))
        entropy_files = dict(self.entropy.files)
        transcript = loads(entropy_files['source/transcript.json'], maximum=current.MAX_BYTES)
        receipt = next(row['result'] for row in transcript['calls']
            if row['method'] == 'eth_getTransactionReceipt' and row.get('result')
            and row['result']['logs'])
        receipt['logs'][0]['address'] = '0x' + '55' * 20
        entropy_files['source/transcript.json'] = dumps(transcript)
        with self.assertRaises(MuseumError): entropy.verify(entropy_files, repin(entropy_files))

    def test_rehashed_assessment_edit_and_preflight_reject(self):
        files = dict(self.result.files)
        assessment = loads(files[current.ASSESSMENT_PATH], maximum=current.MAX_BYTES)
        assessment['results'][1]['state'] = 'missing'
        files[current.ASSESSMENT_PATH] = dumps(assessment)
        with self.assertRaises(MuseumError): current.verify(files, repin(files))
        with patch.object(current.dossier, 'verify', side_effect=AssertionError('source read')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                current.compose({}, '0x' + '11' * 32, disclosure='restricted')
            with self.assertRaisesRegex(MuseumError, 'required together'):
                current.compose({}, '0x' + '11' * 32, finality_files={}, disclosure='public')

    def test_supplemental_only_same_state_positive_conflict_is_not_hidden(self):
        # V4 accepts these exact independent supplements. A subsequent capture
        # can contradict one supplemental getter at its block while canonical
        # sources alone have no observation for that host/getter.
        with patch('socket.socket', side_effect=AssertionError('fixture used network')):
            case = complete_case_v4(); files, digest, options = case.inputs()
            full = v4.compose(files, digest, **options)
            assessed = current.compose(dict(full.files), full.manifest_hash, disclosure='public')
        checked = dict(full.files)
        rows = current.joined_dossier._v4_sources(checked)
        names = {row['name'] for row in rows}
        self.assertTrue(any(name.startswith('production/') for name in names))
        self.assertTrue(any(name.startswith('transfer/') for name in names))
        self.assertFalse(any(name.startswith('general/') for name in names))  # nested alias
        comparison = loads(dict(assessed.files)[current.COMPARISON_PATH], maximum=current.MAX_BYTES)
        self.assertEqual({row['name'] for row in comparison['sourceReconciliation']['sources']}, names)
        canonical = current.observations.sources(current._sub(checked, 'canonical/'))
        canonical_pins = {address for row in canonical for address in row['runtimePins']}
        supplemental = next(row for row in rows if row['name'] == 'production/artist')
        call = next(row for row in supplemental['transcript']['calls']
            if row['method'] == 'eth_call' and row.get('result') is not None
            and row['params'][0]['to'] not in canonical_pins)
        address = call['params'][0]['to']
        attached = {'kind': 'rpc', 'name': 'current-capture',
            'anchor': deepcopy(supplemental['anchor']),
            'runtimePins': {address: supplemental['runtimePins'][address]},
            'provenance': supplemental['provenance'],
            'configuration': deepcopy(supplemental['configuration']),
            'transcript': {'version': 1, 'calls': [deepcopy(call)]}}
        attached['transcript']['calls'][0]['result'] = '0x00'
        source = full.report['sourceState']
        current.observations.reconcile(source, canonical + [attached])
        with self.assertRaisesRegex(MuseumError, 'conflicting positive RPC outcome'):
            current.observations.reconcile(source, rows + [attached])


if __name__ == '__main__': unittest.main()
