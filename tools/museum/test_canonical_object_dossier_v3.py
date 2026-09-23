"""Original conservation Archive observations participate in the common join."""
from copy import deepcopy
import unittest

from . import canonical_object_dossier_v3 as dossier
from .canonical import MuseumError, keccak256
from .test_conservation_archive_v1 import complete_case


class DossierConservationJoinTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = []
        for backend in ('external', 'onchain'):
            source, raw, materials = complete_case(backend)
            result = dossier.conservation.build(dict(source.files), source.manifest_hash,
                raw, keccak256(raw), materials, disclosure='public')
            replayed = dossier.conservation.verify(dict(result.files), result.manifest_hash)
            sources = dossier._conservation_sources(dict(replayed.files), replayed.report['sourceProvenance'])
            reference = {key: replayed.report['sourceState'][key] for key in dossier.observations.STATE_KEYS}
            cls.cases.append((backend, sources, reference))

    def test_both_original_archive_backends_recover_concrete_observations(self):
        for backend, sources, reference in self.cases:
            with self.subTest(backend=backend):
                self.assertEqual([s['kind'] for s in sources], ['rpc', 'native'])
                self.assertGreater(len(sources[1]['calls']), 100)
                report = dossier.observations.reconcile(reference, sources)
                self.assertGreater(report['successfulGetterCount'], 100)
                self.assertFalse(report['claims']['globalHistoryCompletenessProven'])

    def test_cross_family_archive_getter_conflict_is_not_hidden(self):
        for backend, sources, reference in self.cases:
            with self.subTest(backend=backend):
                conflicting = deepcopy(sources[1])
                conflicting['name'] = 'different-current-family'
                conflicting['calls'] = [deepcopy(conflicting['calls'][0])]
                conflicting['calls'][0]['result'] = '0x' + '12' * 32
                with self.assertRaisesRegex(MuseumError, 'conflicting getter'):
                    dossier.observations.reconcile(reference, sources + [conflicting])

    def test_cross_family_archive_runtime_conflict_is_not_hidden(self):
        _, sources, reference = self.cases[0]
        conflicting = deepcopy(sources[1])
        conflicting['name'] = 'different-runtime-family'
        address = next(iter(conflicting['runtimePins']))
        conflicting['runtimePins'][address] = keccak256(b'another runtime')
        with self.assertRaisesRegex(MuseumError, 'conflicting runtime'):
            dossier.observations.reconcile(reference, sources + [conflicting])

    def test_conservation_state_cannot_be_relabelled_for_another_packet(self):
        _, sources, reference = self.cases[0]
        reference = dict(reference, tokenId=str(int(reference['tokenId']) + 1))
        with self.assertRaisesRegex(MuseumError, 'source state differs: tokenId'):
            dossier.observations.reconcile(reference, sources)


if __name__ == '__main__':
    unittest.main()
