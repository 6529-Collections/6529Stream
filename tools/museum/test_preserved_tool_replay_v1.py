"""Closed replay inputs and real process refusal behavior, without a native build."""
from copy import deepcopy
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory
import sys
import unittest

from . import preserved_tool_replay_v1 as replay
from .canonical import MuseumError, dumps, keccak256


class ReplayVectorTests(unittest.TestCase):
    def setUp(self):
        self.files = {'manifest.json': b'{}', 'original.json': b'{"unchanged":true}'}
        self.case = {'id': 'first', 'kind': 'packet_v10', 'files': self.files,
            'manifestHash': keccak256(self.files['manifest.json'])}

    def sources(self, cases=None):
        return {'vectors/' + p: b for p, b in replay.vector_inputs(cases or [self.case]).items()}

    def test_all_exact_input_occurrences_round_trip(self):
        second = dict(self.case, id='second', kind='dossier_v3')
        result = replay.admit_vectors(self.sources([second, self.case]))
        self.assertEqual(result, [self.case, second])

    def test_ignored_vector_refused(self):
        files = self.sources()
        files['vectors/undeclared.json'] = b'{}'
        with self.assertRaisesRegex(MuseumError, 'ignored'):
            replay.admit_vectors(files)

    def test_omitted_original_manifest_refused(self):
        files = self.sources()
        del files['vectors/cases/first/manifest.json']
        with self.assertRaisesRegex(MuseumError, 'manifest pin'):
            replay.admit_vectors(files)

    def test_wrong_kind_duplicate_case_and_command_injection_refused(self):
        for value in (dict(self.case, kind='arbitrary-command'), dict(self.case, id='../escape'),
                dict(self.case, command='python another.py'), dict(self.case, manifestHash=keccak256(b'changed'))):
            with self.subTest(value=value), self.assertRaises(MuseumError):
                replay.vector_inputs([value])
        with self.assertRaisesRegex(MuseumError, 'duplicate'):
            replay.vector_inputs([self.case, self.case])

    def test_rehashed_descriptor_cannot_escape_case_root(self):
        files = self.sources()
        files['vectors/replay-vectors.json'] = dumps({'schema': replay.VECTOR_SCHEMA,
            'cases': [{'id': 'first', 'kind': 'packet_v10', 'root': '../elsewhere',
                'manifestHash': self.case['manifestHash']}]})
        with self.assertRaisesRegex(MuseumError, 'path differs'):
            replay.admit_vectors(files)

    def test_rehashed_descriptor_cannot_silently_drop_case(self):
        files = self.sources([self.case, dict(self.case, id='second')])
        files['vectors/replay-vectors.json'] = self.sources()['vectors/replay-vectors.json']
        with self.assertRaisesRegex(MuseumError, 'ignored'):
            replay.admit_vectors(files)

    def test_vector_format_does_not_establish_semantic_acceptance(self):
        # A syntactically admitted but invalid package must still fail the
        # independent concrete source consumer before a successful result publishes.
        with self.assertRaises(MuseumError):
            replay._expected(replay.admit_vectors(self.sources()))


class ReplayProcessTests(unittest.TestCase):
    def test_failed_child_is_refused_with_bounded_diagnostic(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            worker = root / 'worker.py'
            worker.write_text('raise RuntimeError("intentional refusal")\n', encoding='utf-8')
            with self.assertRaisesRegex(MuseumError, 'intentional refusal'):
                replay._child(Path(sys.executable), worker, root, 5)

    def test_timeout_stops_exact_created_child(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            worker = root / 'worker.py'
            worker.write_text('import time\ntime.sleep(20)\n', encoding='utf-8')
            with self.assertRaisesRegex(MuseumError, 'timed out'):
                replay._child(Path(sys.executable), worker, root, 1)

    def test_output_bound_stops_child(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            worker = root / 'worker.py'
            worker.write_text('import sys\nsys.stdout.write("x" * 1100000)\n', encoding='utf-8')
            with self.assertRaisesRegex(MuseumError, 'output bound'):
                replay._child(Path(sys.executable), worker, root, 5)


class SourceToolchainBindingTests(unittest.TestCase):
    def setUp(self):
        self.parts = b'{"original":"runtime manifest"}\n'
        self.recipe = dumps({'pythonVersion': '3.13.13'})
        self.parts_pin = sha256(self.parts).hexdigest()
        self.recipe_pin = sha256(self.recipe).hexdigest()
        self.source = {'externalPins': [
            {'name': 'runtime', 'role': 'runtime', 'sha256': self.parts_pin, 'bytes': len(self.parts)},
            {'name': 'recipe', 'role': 'system', 'sha256': self.recipe_pin, 'bytes': len(self.recipe)}],
            'prerequisites': [{'name': 'CPython', 'pin': 'runtime', 'version': '3.13.13'}]}

    def check(self, source=None, parts=None, recipe=None):
        replay.validate_toolchain(source or self.source, {'parts.json': parts or self.parts},
            recipe or self.recipe, self.parts_pin, self.recipe_pin)

    def test_exact_runtime_and_recipe_are_bound_inside_source_archive(self):
        self.check()

    def test_individually_pinned_but_unrelated_toolchain_is_refused(self):
        for mutate in (lambda s:s['externalPins'][0].update(sha256='0'*64),
                lambda s:s['externalPins'][0].update(bytes=len(self.parts)+1),
                lambda s:s['externalPins'].pop(),
                lambda s:s['prerequisites'][0].update(pin='recipe'),
                lambda s:s['prerequisites'][0].update(version='3.13.7')):
            changed = deepcopy(self.source); mutate(changed)
            with self.subTest(mutation=mutate), self.assertRaises(MuseumError):
                self.check(changed)

if __name__ == '__main__':
    unittest.main()
