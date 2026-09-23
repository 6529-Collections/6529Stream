"""Version dispatch keeps real prior packet reconstruction and trust boundaries."""
from copy import deepcopy
import unittest

from . import canonical_packet_inputs_v1 as dispatch
from . import acquisition_title_v5 as title
from . import acquisition_scoped_policy_finality_v9 as scoped
from . import object_dossier as package
from .canonical import MuseumError, dumps, keccak256, loads
from .title_v5_fixture import TitleV5Fixture
from .scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2


class PriorPacketTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base = TitleV5Fixture()
        cls.v5 = title.compose(*sum(([r.files, r.manifest_hash] for r in base.title_inputs()), []), disclosure='public')
        native = ScopedPolicyFinalityFixtureV2()
        cls.v9 = scoped.compose(*sum(([r.files, r.manifest_hash] for r in native.policy_inputs()), []), disclosure='public')

    def test_exact_v5_and_original_undeclared_owner_collection(self):
        before = deepcopy(self.v5.files)
        result = dispatch.admit(self.v5.files, self.v5.manifest_hash)
        self.assertEqual(result.files, self.v5.files)
        self.assertEqual(result.packet['schema'], 'STREAM_ACQUISITION_PACKET_V5')
        self.assertEqual(len(result.observations), 11)
        owner = next(s for s in result.observations if s['name'].endswith('/sources/owner/'))
        self.assertNotIn('collectionId', owner['anchor'])
        self.assertEqual(result.reference['collectionId'], result.packet['sourceState']['collectionId'])
        self.assertEqual(before, self.v5.files)

    def test_v9_finality_keeps_exact_native_version_and_proof(self):
        result = dispatch.admit(self.v9.files, self.v9.manifest_hash)
        self.assertEqual(result.files, self.v9.files)
        self.assertEqual(len(result.observations), 12)
        self.assertEqual(result.packet['finality']['kind'], 'native_scoped_policy_finality_v2')
        self.assertEqual(result.packet['contentRootProof']['kind'], 'native_scoped_policy_token_content_proof_v2')
        self.assertFalse(result.report['canonicalPacketReady'])

    def test_external_pin_precedes_version_dispatch(self):
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            dispatch.admit(self.v5.files, keccak256(b'other manifest'))

    def test_unknown_version_refused(self):
        files = dict(self.v5.files)
        value = loads(files['manifest.json'], maximum=1048576, canonical=True)
        value['mode'] = 'caller_says_latest'
        files['manifest.json'] = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'unsupported prior version'):
            dispatch.admit(files, keccak256(files['manifest.json']))

    def test_rehashed_claim_cannot_replace_original_replay(self):
        files = dict(self.v5.files)
        path = next(p for p in files if p.endswith('title/assembly.json'))
        value = loads(files[path], maximum=16777216, canonical=True)
        value['canonicalPacketReady'] = True
        files[path] = dumps(value)
        manifest = loads(files['manifest.json'], maximum=1048576, canonical=True)
        manifest['files'] = [package._ref(p, raw) for p, raw in sorted(files.items()) if p != 'manifest.json']
        files['manifest.json'] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, 'reconstruction differs'):
            dispatch.admit(files, keccak256(files['manifest.json']))


if __name__ == '__main__':
    unittest.main()
