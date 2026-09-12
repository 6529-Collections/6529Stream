"""Adversarial extension input tests, including attempts to rewrite the frozen prefix."""

import copy
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from tools.protocol import check_artist_operation_extension as checker

ROOT = Path(__file__).resolve().parents[2]


class ArtistOperationExtensionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for path in [checker.MANIFEST, *map(Path, checker.HISTORICAL)]:
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / path, target)
        self.manifest = json.loads((self.root / checker.MANIFEST).read_bytes())

    def write_manifest(self, manifest):
        (self.root / checker.MANIFEST).write_bytes((json.dumps(manifest)+'\n').encode())

    def reject(self, mutate, message=None):
        value = copy.deepcopy(self.manifest)
        mutate(value)
        self.write_manifest(value)
        with self.assertRaisesRegex(checker.ExtensionError, message or '.'):
            checker.check(self.root)

    def test_exact_effective_prefix_and_pending_boundary(self):
        rows = checker.validate(self.root, self.manifest)
        base = json.loads((self.root / checker.BASE).read_bytes())
        self.assertEqual(rows[:57], base['operations'])
        self.assertEqual([row[0] for row in rows], list(range(1,59)))
        result = checker.check(self.root)
        self.assertFalse(result['implementation_accepted'])
        with self.assertRaisesRegex(checker.ExtensionError, 'implementation acceptance unavailable'):
            checker.check(self.root, require_implementation=True)

    def test_historical_field_edit_even_if_manifest_rehashes_it(self):
        path = self.root / checker.BASE
        value = json.loads(path.read_bytes())
        value['operations'][32][7] = 'BYPASS'
        path.write_bytes(json.dumps(value).encode())
        with self.assertRaisesRegex(checker.ExtensionError, 'historical bytes changed'):
            checker.check(self.root)
        self.reject(lambda m: m['historical_inputs'][0].update(sha256=checker.hashlib.sha256(path.read_bytes()).hexdigest()), 'historical hash inventory')

    def test_historical_schema_bytes_cannot_drift(self):
        path = next(p for p in checker.HISTORICAL if p.endswith('.schema.json'))
        target = self.root / path
        target.write_bytes(target.read_bytes()+b' ')
        with self.assertRaisesRegex(checker.ExtensionError, 'historical bytes changed'):
            checker.check(self.root)

    def test_missing_reordered_duplicate_and_boolean_ids_rejected(self):
        mutations = [
            lambda m: m['effective_inventory']['historical_ids'].reverse(),
            lambda m: m['effective_inventory']['historical_ids'].pop(),
            lambda m: m['operations'].append(copy.deepcopy(m['operations'][0])),
            lambda m: m['operations'][0].__setitem__(0, 57),
            lambda m: m['operations'][0].__setitem__(0, True),
            lambda m: m['operations'][0].pop(),
            lambda m: m['operation_columns'].reverse(),
        ]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                self.reject(mutate)

    def test_stop_overlay_cannot_be_dropped(self):
        for mutate in [lambda m: m['implementation_stops'].clear(),
                       lambda m: m['operations'][0][-1].clear(),
                       lambda m: m['effective_inventory'].update(historical_stop_overlays='cleared')]:
            self.reject(mutate)

    def test_flattened_tuple_and_semantic_abi_substitution_rejected(self):
        self.reject(lambda m: m['abi'].update(write_signature='dismissArtistIdentityContest(bytes32,bytes32,bytes32,bytes32,bytes32,bool,bytes32)'), 'exact Request')
        self.reject(lambda m: m['abi'].update(validation_signature='identityContestDismissalContext(bytes32,bytes32,bytes32,bytes32,bytes32,bool,bytes32)'), 'validation surface')
        self.reject(lambda m: m['operations'][0].__setitem__(4,'0x1ae10cc1'), 'semantic write')

    def test_selector_collision_and_fake_hash_rejected(self):
        self.reject(lambda m: m['abi']['public_methods'][1].update(selector=m['abi']['public_methods'][0]['selector']), 'selector collision')
        self.reject(lambda m: m['abi']['public_methods'][0].update(selector='0x12345678'), 'selector/preimage')
        self.reject(lambda m: m['domains'][0].update(hash='0x'+'00'*32), 'domain preimage')

    def test_owner_mask_field_width_and_authority_drift_rejected(self):
        for mask in ['snapshot_mask','read_mask','write_mask']:
            self.reject(lambda m: m['recipe'].update({mask:'0x24'}), 'Identity-only')
        self.reject(lambda m: m['recipe'].update(payout_access='READ'), 'Payout')
        self.reject(lambda m: m['recipe'].update(authority_classes=[1,2,3]), 'authority')
        self.reject(lambda m: m['types']['Request'][5].update(type='uint8'), 'request field')
        self.reject(lambda m: m['operations'][0].__setitem__(9,'0x00003f'), 'field mask')

    def test_record_reconstruction_and_indexed_event_drift_rejected(self):
        self.reject(lambda m: m['record_event_join']['fields'].pop('Request.expectedCauseHash'), 'preimage field')
        self.reject(lambda m: m['record_event_join']['fields'].update(executor='notAnEventField'), 'absent event')
        self.reject(lambda m: m['events'][0]['fields'][4].update(indexed=True), 'indexed fields')
        self.reject(lambda m: m['events'][1]['fields'][3].update(type='uint16'), 'event signature')
        self.reject(lambda m: m['hash_recipes']['record'].append('revisionContinuationHead'))

    def test_per_call_replay_and_cause_consumer_prerequisites_rejected(self):
        self.reject(lambda m: m['replay'][1].update(scope=['actionId']), 'per-call')
        self.reject(lambda m: m['source_prerequisites'][0].update(operations=[33]), 'cause')
        self.reject(lambda m: m['source_prerequisites'].pop(), 'prerequisites')
        self.reject(lambda m: m['archive'].update(owner='payout_lifecycle'), 'Archive')

    def test_unknown_field_status_and_duplicate_json_members_rejected(self):
        self.reject(lambda m: m.update(unreviewed_extra='drift'), 'reviewed design')
        self.reject(lambda m: m.update(status='IMPLEMENTED'), 'cannot claim')
        (self.root / checker.MANIFEST).write_bytes(b'{"schema":1,"schema":2}')
        with self.assertRaisesRegex(checker.ExtensionError, 'duplicate JSON member'):
            checker.check(self.root)


if __name__ == '__main__':
    unittest.main()
