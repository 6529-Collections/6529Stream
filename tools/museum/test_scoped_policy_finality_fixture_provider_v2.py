"""Synthetic provider fixture checks; no native deployment or network evidence."""
from copy import deepcopy
import socket
import unittest
from unittest.mock import patch

from . import native_scoped_policy_finality_wire_v2 as wire
from . import public_scoped_policy_finality_source_v2 as source
from .canonical import MuseumError, dumps, schema_id
from .conservation_capture_join import COMMON
from .scoped_policy_finality_fixture_provider_v2 import provider_evidence, install_provider_reads
from .scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2


class _ProviderFixture(ScopedPolicyFinalityFixtureV2):
    # This cohort exercises the constructor catalogue and actual binding reads;
    # finality/action construction is independently tested by the full fixture.
    def _complete_bundle(self, artist, adapters, originals):
        pass


class ProviderFixtureTests(unittest.TestCase):
    def fixture(self):
        fixture = _ProviderFixture()
        x, g, factory = fixture.policy_context, fixture.policy_graph, fixture.scoped_policy_factory
        p = provider_evidence(x, g, factory, fixture=fixture)
        return fixture, x, g, factory, p

    def test_original_catalogues_and_factory_selected_roles_stay_distinct(self):
        f, x, g, factory, p = self.fixture(); c = p['configuration']
        wire.validate_provider(c, x, g, factory)
        for index in (6, 7):
            self.assertEqual({c[key][0][index] for key in ('originalConfiguration',
                'scopedConfiguration', 'policyConfiguration')}, {c['originalConfiguration'][0][index]})
            self.assertNotEqual(c['selectedConfiguration'][0][index], c['originalConfiguration'][0][index])
        self.assertNotEqual(c['collectionPolicyOutput']['address'], g['outputManifest']['address'])
        self.assertEqual(len(p['adapters']), 7)
        self.assertEqual(c['selectedConfiguration'][0][8], g['policySnapshot']['address'])
        self.assertEqual(provider_evidence(x, g, factory), p)

    def test_selected_original_or_profile_substitution_rejected(self):
        f, x, g, factory, p = self.fixture()
        for key in ('selectedConfiguration', 'scopedConfiguration'):
            q = deepcopy(p['configuration'])
            q[key][0][0] = q['originalConfiguration'][0][6]
            with self.subTest(key=key), self.assertRaises(MuseumError):
                wire.validate_provider(q, x, g, factory)
        q = deepcopy(p['configuration']); q['profiles'][1][0] = q['profiles'][2][0]
        with self.assertRaisesRegex(MuseumError, 'catalogue hash'):
            wire.validate_provider(q, x, g, factory)

    def test_actual_source_binding_reads_use_same_codes_and_catalogue(self):
        f, x, g, factory, p = self.fixture()
        install_provider_reads(f, p, x, g)
        a = {key: f.a[key] for key in COMMON}
        a.update({key: row['address'] for key, row in g.items()})
        needed = set(a[key] for key in wire.GRAPH_KEYS)
        c = p['configuration']
        for key in ('originalConfiguration', 'scopedConfiguration', 'policyConfiguration'):
            needed.update(c[key][0])
        needed.update(row['address'] for row in p['adapters'])
        needed.add(c['collectionPolicyOutput']['address'])
        a.update(profile=source.PROFILE, tokenId=x['tokenId'], scope=f.scoped_policy_statement[0],
            codePins=[{'address': address, 'runtimeHash': f.pins[address]} for address in sorted(needed)],
            runtimeAdmission={'sourceCommit': source.SOURCE_REVISION, 'kind': 'synthetic_fixture',
                'artifactHash': schema_id('explicit synthetic scoped provider fixture')})
        with patch.object(socket, 'socket', side_effect=AssertionError('network forbidden')):
            observed = source.PublicScopedPolicyFinalitySource(dumps(a), f)
            observed._bindings()
        q = deepcopy(p); q['configuration'].pop('selectedConfiguration')
        self.assertEqual(observed.provider_evidence, q)
        self.assertTrue(observed.reader.rows)

    def test_extra_runtime_installation_refuses_existing_collision(self):
        f, x, g, factory, p = self.fixture()
        address = p['adapters'][0]['address']; f.codes[address] = b'other existing runtime'
        with self.assertRaisesRegex(MuseumError, 'existing runtime collision'):
            install_provider_reads(f, p, x, g)


if __name__ == '__main__':
    unittest.main()
