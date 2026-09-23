"""Exact synthetic native Registry document controls for script interpretation."""
from types import SimpleNamespace
import unittest

from . import token_script_interpretation_v1 as interpretation
from . import token_script_registry_source_v1 as source
from .canonical import MuseumError, dumps, keccak256, loads
from .public_history_rpc import PublicReplayTransport
from .test_genesis_registry_source_v1 import GenesisRegistryFixture


def fixture(*, missing=False, mismatched=False):
    f = GenesisRegistryFixture()
    f.plan = SimpleNamespace(documents=interpretation.documents())
    for index in range(1, 4):
        f.install_document(index, exists=not (missing and index == 2),
            content=(b'{"wrong":"native script profile"}'
                if mismatched and index == 3 else None))
    f.anchor['profile'] = source.PROFILE
    f.anchor_raw = dumps(f.anchor)
    return f


class TokenScriptRegistrySourceTests(unittest.TestCase):
    def test_exact_registered_documents_and_offline_replay(self):
        f = fixture()
        reader = source.TokenScriptRegistrySource(f.anchor_raw, f)
        raw = reader.snapshot(); transcript = reader.transcript()
        value = loads(raw, maximum=source.genesis.MAX_OUTPUT)
        self.assertEqual(len(value['documents']), 4)
        self.assertTrue(all(row['matchesPlan'] and row['currentStatus'] == 'ACTIVE'
            for row in value['documents']))
        replay = source.TokenScriptRegistrySource(f.anchor_raw,
            PublicReplayTransport(transcript, keccak256(transcript)))
        self.assertEqual(replay.snapshot(), raw)

    def test_missing_or_mismatched_document_rejects(self):
        for options in ({'missing': True}, {'mismatched': True}):
            with self.subTest(options=options):
                f = fixture(**options)
                with self.assertRaisesRegex(MuseumError,
                        'registered interpretation missing or differs'):
                    source.TokenScriptRegistrySource(f.anchor_raw, f).snapshot()


if __name__ == '__main__': unittest.main()
