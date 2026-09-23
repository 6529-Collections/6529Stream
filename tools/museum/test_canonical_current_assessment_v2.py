"""Current token-script requirement joins replay originals at one target/state."""
import unittest
from unittest.mock import patch

from . import canonical_current_assessment_v1 as previous
from . import canonical_current_assessment_v2 as current
from . import token_script_capture_v1 as token_capture
from . import token_script_registered_capture_v1 as registered_capture
from .canonical import MuseumError, dumps, keccak256, loads
from . import test_canonical_current_assessment_v1 as previous_tests
from .test_token_script_source_v1 import TokenScriptFixture


class CurrentScriptAssessmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        previous_tests.CurrentAssessmentTests.setUpClass()
        cls.previous = previous_tests.CurrentAssessmentTests.all_five
        cls.base_fixture = previous_tests.CurrentAssessmentTests.fixture
        cls.script = cls.registered('stable')
        cls.result = current.compose(dict(cls.previous.files), cls.previous.manifest_hash,
            script_files=dict(cls.script.files), script_hash=cls.script.manifest_hash,
            disclosure='public')

    @classmethod
    def registered(cls, mode, *, state_override=None, incomplete_dependency=False):
        source_state = dict(cls.previous.report['sourceState'])
        if state_override: source_state.update(state_override)
        original = cls.base_fixture
        addresses = original.scoped_policy_addresses
        context = {'chainId': source_state['chainId'], 'core': source_state['core'],
            'collectionId': source_state['collectionId'], 'metadata': original.a['host'],
            'router': addresses['router'], 'store': addresses['store']}
        shared = (source_state['core'], original.a['host'], addresses['router'],
            addresses['store'])
        runtimes = {address: original.codes[address] for address in shared}
        fixture = TokenScriptFixture(mode, context_overrides=context,
            source_state=source_state, runtime_overrides=runtimes,
            history_offset=-8)
        if incomplete_dependency:
            fixture.fail(fixture.metadata, 'dependencyChunk(bytes32,uint256)',
                ('bytes32', 'uint256'), (fixture.value['library']['bundleId'], 0))
        token = fixture.source(); token.snapshot(); transcript = token.transcript()
        child = token_capture.replay(fixture.anchor_raw,
            keccak256(fixture.anchor_raw), transcript, keccak256(transcript),
            fixture.runtime_bridge_raw, keccak256(fixture.runtime_bridge_raw),
            provenance='synthetic_fixture', disclosure='public')
        registry = fixture.install_registry(schemas_address=addresses['schemas'],
            runtime_overrides={addresses['schemas']: original.codes[addresses['schemas']]})
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


if __name__ == '__main__': unittest.main()
