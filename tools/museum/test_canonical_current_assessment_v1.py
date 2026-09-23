"""Current native-state requirement references are earned from replayed proofs."""
import unittest
from unittest.mock import patch

from . import canonical_current_assessment_v1 as current
from . import canonical_object_dossier_v4 as v4
from . import public_mint_entropy_capture as entropy
from . import public_scoped_policy_finality_capture_v2 as finality
from . import test_canonical_semantic_sources_v2 as source_case
from .canonical import MuseumError, dumps, keccak256, loads
from .canonical_object_dossier_fixture_v4 import canonical_case
from .scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2
from .test_public_mint_entropy_source import PublicMintEntropyFixture


def repin(files):
    manifest = loads(files['manifest.json'], maximum=current.MAX_MANIFEST)
    manifest['files'] = [current.package._ref(path, raw) for path, raw in sorted(files.items())
        if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class CurrentAssessmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        holder = {}

        class CoherentFixture(source_case.AllFamilyOwnerFixture, ScopedPolicyFinalityFixtureV2):
            def __init__(self):
                super().__init__()
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
            entropy_fixture = PublicMintEntropyFixture(source_block=6, recovery=True, late=True)
            adapter = entropy_fixture.source(); adapter.snapshot(); transcript = adapter.transcript()
            cls.entropy = entropy.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
                entropy._source().PROFILE_HASH, transcript, keccak256(transcript),
                provenance='synthetic_fixture', disclosure='public')
            cls.result = current.compose(dict(cls.base.files), cls.base.manifest_hash,
                finality_files=dict(cls.finality.files), finality_hash=cls.finality.manifest_hash,
                disclosure='public')
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


if __name__ == '__main__': unittest.main()
