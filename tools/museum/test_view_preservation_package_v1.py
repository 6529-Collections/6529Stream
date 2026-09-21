"""Full original VIEW inventory replay survives BagIt and OCFL transport."""
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from hashlib import sha256, sha512
from io import StringIO
import json
from pathlib import Path
import socket
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import bagit, ocfl
from . import view_preservation_bagit_v1 as transport
from . import view_preservation_inventory_v1 as consumer
from . import view_preservation_package_v1 as package
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .view_preservation_bundle_fixture_v1 import supplied


def _input(count=1, mode='disabled', burned=False):
    inventory, coverage, context, graph = supplied(count, mode, burned)
    return dumps({'profileHash': consumer.PROFILE_HASH, 'context': context, 'graph': graph,
        'inventory': inventory, 'bundle': coverage})


def _sha(raw):
    return sha256(raw).hexdigest()


def _description(bag):
    return loads(bag.manifest, maximum=bagit.MAX_MANIFEST)['input']


def _payloads(bag):
    return {name[5:]: raw for name, raw in bag.files if name.startswith('data/')}


def _transport_bag(bag, changed=None, omitted=(), description_change=None):
    """Rehash valid transport without supplying new semantic evidence."""
    payloads = _payloads(bag); payloads.update(changed or {})
    for path in omitted: payloads.pop(path)
    description = deepcopy(_description(bag))
    old_rows = {row['path']: row for row in description['payloads']}
    description['payloads'] = []
    for name, raw in sorted(payloads.items()):
        row = deepcopy(old_rows.get(name, {'path': name, 'renderCritical': False,
            'delivery': {'kind': 'embedded'}}))
        row.update(bytes=str(len(raw)), sha256='0x' + _sha(raw), keccak256=keccak256(raw))
        description['payloads'].append(row)
    for name in ('bundleManifest', 'schema'):
        path = description[name]['path']
        if path in payloads: description[name]['hash'] = keccak256(payloads[path])
    if description_change: description_change(description)
    return transport.build_bag(dumps(description), payloads)


def _transport_object(bags):
    """Create coherent OCFL fixity only, so an old semantic lie reaches replay.

    No semantic verifier is patched. The test builds all native OCFL inventories,
    states, content addresses and sidecars; acceptance still uses production.
    """
    first = _description(bags[0])
    identifier = transport.identity(first['scope'], first['externalIdentifier'])
    files = {ocfl.DECLARATION_NAME: ocfl.DECLARATION}
    inventory = {'id': identifier, 'type': ocfl.INVENTORY_TYPE, 'digestAlgorithm': 'sha256',
        'head': 'v1', 'contentDirectory': 'content', 'manifest': {}, 'versions': {}, 'fixity': {'sha512': {}}}
    for number, bag in enumerate(bags, 1):
        head = 'v' + str(number); state = {}
        for name, raw in bag.files:
            digest = _sha(raw); state.setdefault(digest, []).append('bag/' + name)
            if digest not in inventory['manifest']:
                path = head + '/content/' + digest
                files[path] = raw; inventory['manifest'][digest] = [path]
                inventory['fixity']['sha512'].setdefault(sha512(raw).hexdigest(), []).append(path)
        inventory['versions'][head] = {'created': f'2026-09-21T0{number}:00:00Z',
            'message': 'test retained version ' + str(number), 'state': state}
        inventory['head'] = head; raw = dumps(inventory)
        sidecar = (_sha(raw) + '  inventory.json\n').encode()
        files.update({'inventory.json': raw, 'inventory.json.sha256': sidecar,
            head + '/inventory.json': raw, head + '/inventory.json.sha256': sidecar})
    return ocfl.ObjectVersion(tuple(sorted(files.items())), raw)


class ViewPreservationPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = _input()
        cls.bag = package.build(cls.raw, _sha(cls.raw), disclosure='public', bagging_date='2026-09-21')

    def build(self, raw=None, **options):
        raw = self.raw if raw is None else raw
        return package.build(raw, _sha(raw), disclosure=options.pop('disclosure', 'public'),
            bagging_date=options.pop('bagging_date', '2026-09-21'), **options)

    def test_complete_originals_determinism_offline_and_generic_dispatch(self):
        with patch.object(socket, 'socket', side_effect=AssertionError('network disabled')):
            rebuilt = self.build()
            self.assertEqual(rebuilt, self.bag)
            self.assertEqual(package.verify_files(dict(rebuilt.files), rebuilt.manifest_hash), rebuilt)
            self.assertEqual(bagit.verify_bag_files(rebuilt.files, rebuilt.manifest_hash), rebuilt)
        files = dict(rebuilt.files); payloads = _payloads(rebuilt)
        self.assertIn(self.raw, payloads.values())
        self.assertIn(consumer.PROFILE_BYTES, payloads.values())
        self.assertEqual(files['stream-bagit-profile.json'], transport.PROFILE_BYTES)
        value = loads(self.raw, maximum=consumer.MAX_INPUT)
        for member in value['inventory']['members']:
            for key in ('outputReturn', 'tokenData', 'json', 'html'):
                self.assertIn(hex_bytes(member[key]), payloads.values())
        description = _description(rebuilt)
        self.assertEqual(description['sourceMode'], 'synthetic_fixture')
        self.assertTrue(description['externalIdentifier'].startswith('urn:6529stream:view-scope:'))
        self.assertNotIn('/erc721:', description['externalIdentifier'])
        self.assertEqual(set(description['scope']), {'chainId', 'core', 'collectionId', 'scopeId', 'blockNumber', 'blockHash'})
        self.assertEqual(loads(rebuilt.manifest)['selfContainment'], 'self_contained')
        self.assertNotIn('fetch.txt', files)
        evidence = loads(payloads[package.MANIFEST_PATH])
        self.assertTrue(evidence['claims']['completeRetainedInventoryReplayed'])
        self.assertFalse(evidence['claims']['rpcProvenanceAuthenticated'])
        self.assertFalse(evidence['claims']['currentFinalityProven'])
        self.assertFalse(loads(payloads['tool/source-index.json'])['completeRuntimeArchive'])

    def test_three_members_original_burn_and_finalized_entropy_preserved(self):
        raw = _input(3, 'finalized', True); bag = self.build(raw)
        value = loads(raw, maximum=consumer.MAX_INPUT)
        payloads = _payloads(bag)
        self.assertEqual(package.verify_files(dict(bag.files), bag.manifest_hash), bag)
        for member in value['inventory']['members']:
            for key in ('outputReturn', 'tokenData', 'json', 'html'):
                self.assertIn(hex_bytes(member[key]), payloads.values())
        self.assertEqual(sum(name.endswith('.output.abi') for name in payloads), 3)

    def test_public_disclosure_external_sha_and_canonical_input_required(self):
        for disclosure in ('restricted', '', None):
            with self.subTest(disclosure=disclosure):
                with patch.object(consumer, 'verify', side_effect=AssertionError('disclosure before replay')):
                    with self.assertRaises(MuseumError): self.build(disclosure=disclosure)
        for digest in ('0' * 64, '0x' + _sha(self.raw), _sha(self.raw).upper()):
            with self.subTest(digest=digest[:8]):
                with self.assertRaises(MuseumError):
                    package.build(self.raw, digest, disclosure='public', bagging_date='2026-09-21')
        with self.assertRaises(MuseumError): self.build(self.raw + b'\n')
        with self.assertRaises(MuseumError): self.build(bagging_date='2026-02-30')

    def test_rehashed_member_omission_alteration_and_extra_payload_rejected(self):
        payloads = _payloads(self.bag)
        members = loads(self.raw, maximum=consumer.MAX_INPUT)['inventory']['members']
        target = next(name for name, raw in payloads.items() if raw == hex_bytes(members[0]['html']))
        variants = (_transport_bag(self.bag, omitted=(target,)),
            _transport_bag(self.bag, changed={target: b'<html>different original</html>'}),
            _transport_bag(self.bag, changed={'unexpected.json': b'{}'}))
        for changed in variants:
            transport.verify_files_transport(dict(changed.files), changed.manifest_hash)
            with self.subTest(manifest=changed.manifest_hash):
                with self.assertRaises(MuseumError): package.verify_files(dict(changed.files), changed.manifest_hash)

    def test_report_and_profile_cannot_be_rewritten_under_new_manifest(self):
        payloads = _payloads(self.bag)
        for name in (package.REPORT_PATH, package.SCHEMA_PATH,
                next(name for name, raw in payloads.items() if raw == consumer.PROFILE_BYTES)):
            changed = _transport_bag(self.bag, changed={name: b'{}'})
            transport.verify_files_transport(dict(changed.files), changed.manifest_hash)
            with self.subTest(name=name):
                with self.assertRaises(MuseumError): package.verify_files(dict(changed.files), changed.manifest_hash)

    def test_rehashed_original_evidence_still_runs_native_consumer(self):
        original = loads(self.raw, maximum=consumer.MAX_INPUT)
        original['inventory']['events'].pop()
        altered = dumps(original)
        with self.assertRaises(MuseumError): consumer.verify(altered)
        input_name = next(name for name, raw in _payloads(self.bag).items() if raw == self.raw)
        manifest = loads(_payloads(self.bag)[package.MANIFEST_PATH])
        manifest.update(inputSHA256=_sha(altered), inputHash=keccak256(altered))
        changed = _transport_bag(self.bag, changed={input_name: altered, package.MANIFEST_PATH: dumps(manifest)})
        transport.verify_files_transport(dict(changed.files), changed.manifest_hash)
        with self.assertRaises(MuseumError): package.verify_files(dict(changed.files), changed.manifest_hash)

    def test_caller_provenance_is_preserved_and_never_upgraded(self):
        value = loads(self.raw, maximum=consumer.MAX_INPUT)
        value['inventory']['recordedSource']['provenance'] = 'externally_admitted_rpc'
        value['bundle']['sourceBindings']['provenance'] = 'externally_admitted_rpc'
        raw = dumps(value); bag = self.build(raw)
        self.assertEqual(_description(bag)['sourceMode'], 'externally_admitted_rpc')
        self.assertIn(raw, _payloads(bag).values())
        self.assertEqual(package.verify_files(dict(bag.files), bag.manifest_hash), bag)
        self.assertTrue(all(flag is False for flag in loads(bag.manifest)['qualification'].values()))
        value['bundle']['sourceBindings']['provenance'] = 'synthetic_fixture'
        with self.assertRaises(MuseumError): self.build(dumps(value))

    def test_directory_verification_is_read_only_and_strictly_bounded(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary) / 'bag'; bagit.write_tree(self.bag.files, root)
            before = bagit.read_tree(root)
            self.assertEqual(package.verify(root, self.bag.manifest_hash), self.bag)
            self.assertEqual(bagit.read_tree(root), before)
            extra = root / 'extra'; extra.write_bytes(b'not declared')
            with self.assertRaises(MuseumError): package.verify(root, self.bag.manifest_hash)
            extra.unlink()
            empty = root / 'empty'; empty.mkdir()
            with self.assertRaises(MuseumError): package.verify(root, self.bag.manifest_hash)
        for path in ('../outside', '/absolute', 'data/../escape', 'data\\escape', 'CON'):
            files = dict(self.bag.files); files[path] = b'bad'
            with self.subTest(path=path):
                with self.assertRaises(MuseumError): package.verify_files(files, self.bag.manifest_hash)

    def test_symlink_file_is_not_an_embedded_original(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary) / 'bag'; bagit.write_tree(self.bag.files, root)
            target = Path(temporary) / 'target'; target.write_bytes(b'bytes')
            link = root / 'symlink'
            try: link.symlink_to(target)
            except (OSError, NotImplementedError) as exc: self.skipTest('local symlink capability unavailable: ' + str(exc))
            with self.assertRaises(MuseumError): package.verify(root, self.bag.manifest_hash)

    def test_two_ocfl_versions_keep_scope_predecessor_and_all_original_bytes(self):
        first = package.build_ocfl(self.bag, created='2026-09-21T01:00:00Z', message='initial')
        successor = self.build(predecessor=self.bag.manifest_hash)
        second = package.build_ocfl(successor, created='2026-09-21T02:00:00Z', message='successor',
            previous=first, previous_inventory_hash=first.inventory_hash)
        self.assertEqual(package.verify_ocfl_files(dict(second.files), second.inventory_hash), second)
        self.assertEqual(ocfl.verify_object_files(second.files, second.inventory_hash), second)
        inventory = loads(second.inventory)
        self.assertEqual(inventory['head'], 'v2')
        self.assertEqual(inventory['id'], _description(self.bag)['externalIdentifier'].split('@')[0])
        for name, raw in first.files:
            if name.startswith('v1/'): self.assertEqual(dict(second.files)[name], raw)
        restored = []
        for name in ('v1', 'v2'):
            bag, _ = ocfl._bag_for_state(dict(second.files), inventory, inventory['versions'][name]['state'])
            restored.append(bag)
            self.assertIn(self.raw, _payloads(bag).values())
        self.assertEqual(restored, [self.bag, successor])

    def test_ocfl_identity_predecessor_pin_and_time_cannot_drift(self):
        first = package.build_ocfl(self.bag, created='2026-09-21T01:00:00Z', message='initial')
        successor = self.build(predecessor=self.bag.manifest_hash)
        for bag, created, previous_pin in (
                (self.build(predecessor=keccak256(b'wrong')), '2026-09-21T02:00:00Z', first.inventory_hash),
                (successor, '2026-09-21T01:00:00Z', first.inventory_hash),
                (successor, '2026-09-21T02:00:00Z', keccak256(b'wrong'))):
            with self.assertRaises(MuseumError):
                package.build_ocfl(bag, created=created, message='bad lineage', previous=first,
                    previous_inventory_hash=previous_pin)
        def change_scope(description):
            description['scope']['scopeId'] = keccak256(b'different VIEW scope')
            description['externalIdentifier'] = transport.external_identifier(description['scope'])
        wrong_scope = _transport_bag(successor, description_change=change_scope)
        with self.assertRaises(MuseumError):
            package.build_ocfl(wrong_scope, created='2026-09-21T02:00:00Z', message='wrong scope',
                previous=first, previous_inventory_hash=first.inventory_hash)

    def test_coherently_rehashed_old_version_still_requires_semantic_replay(self):
        control_head = self.build(predecessor=self.bag.manifest_hash)
        control = _transport_object((self.bag, control_head))
        self.assertEqual(package.verify_ocfl_files(dict(control.files), control.inventory_hash), control)
        wrong_first = _transport_bag(self.bag, changed={package.REPORT_PATH: b'{}'})
        transport.verify_files_transport(dict(wrong_first.files), wrong_first.manifest_hash)
        valid_head = self.build(predecessor=wrong_first.manifest_hash)
        forged = _transport_object((wrong_first, valid_head))
        with self.assertRaises(MuseumError): package.verify_ocfl_files(dict(forged.files), forged.inventory_hash)
        with self.assertRaises(MuseumError): ocfl.verify_object_files(forged.files, forged.inventory_hash)

    def test_cli_offline_profiles_build_verify_ocfl_and_no_overwrite(self):
        def cli(args, expected=0):
            stdout, stderr = StringIO(), StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr): code = package.main(args)
            self.assertEqual(code, expected, stderr.getvalue())
            return json.loads(stdout.getvalue()) if code == 0 else stderr.getvalue()
        with TemporaryDirectory() as temporary, patch.object(socket, 'socket', side_effect=AssertionError('network disabled')):
            base = Path(temporary); original = base / 'input.json'; original.write_bytes(self.raw)
            bag_path, object_path = base / 'bag', base / 'object'
            profile = cli(['profiles'])
            self.assertEqual(profile['profileHash'], transport.PROFILE_HASH)
            build_args = ['build', str(original), str(bag_path), '--inventory-sha256', _sha(self.raw),
                '--disclosure', 'public', '--bagging-date', '2026-09-21']
            report = cli(build_args); before = bagit.read_tree(bag_path)
            self.assertEqual(report['manifestHash'], self.bag.manifest_hash)
            self.assertEqual(cli(['verify', str(bag_path), '--manifest-hash', self.bag.manifest_hash])['manifestHash'], self.bag.manifest_hash)
            cli(build_args, 1)
            self.assertEqual(bagit.read_tree(bag_path), before)
            ocfl_args = ['ocfl', str(bag_path), str(object_path), '--manifest-hash', self.bag.manifest_hash,
                '--created', '2026-09-21T01:00:00Z', '--message', 'original immutable object']
            object_report = cli(ocfl_args); object_before = bagit.read_tree(object_path)
            self.assertEqual(cli(['verify-ocfl', str(object_path), '--inventory-hash',
                object_report['inventoryHash']])['inventoryHash'], object_report['inventoryHash'])
            cli(ocfl_args, 1)
            self.assertEqual(bagit.read_tree(object_path), object_before)
            self.assertEqual(original.read_bytes(), self.raw)

    def test_restricted_cli_rejects_before_reading_input(self):
        with patch.object(Path,'open',side_effect=AssertionError('input must not be opened')):
            stderr = StringIO()
            with redirect_stderr(stderr):
                result = package.main(['build','unread-input.json','uncreated-output',
                    '--inventory-sha256',_sha(self.raw),'--disclosure','restricted','--bagging-date','2026-09-21'])
            self.assertEqual(result,1)
            self.assertIn('explicit public disclosure',stderr.getvalue())

    def test_cli_bad_pin_or_disclosure_never_creates_destination(self):
        with TemporaryDirectory() as temporary:
            base = Path(temporary); original = base / 'input.json'; original.write_bytes(self.raw)
            for index, (pin, disclosure) in enumerate((('0' * 64, 'public'), (_sha(self.raw), 'restricted'))):
                output = base / ('bad' + str(index))
                with redirect_stderr(StringIO()), redirect_stdout(StringIO()):
                    code = package.main(['build', str(original), str(output), '--inventory-sha256', pin,
                        '--disclosure', disclosure, '--bagging-date', '2026-09-21'])
                self.assertEqual(code, 1)
                self.assertFalse(output.exists())


if __name__ == '__main__': unittest.main()
