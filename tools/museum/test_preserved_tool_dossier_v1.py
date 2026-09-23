"""Supplement refuses authority upgrades and preserves explicit execution scope."""
from copy import deepcopy
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from . import object_dossier as package
from . import preserved_tool_dossier_v1 as supplement
from . import preserved_tool_replay_v1 as replay
from .canonical import MuseumError, dumps


class SupplementBoundaryTests(unittest.TestCase):
    def test_disclosure_refused_before_missing_paths_are_read_or_code_runs(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(MuseumError, 'before reads/execution'):
                supplement.assemble(root / 'absent', 'bad', root / 'absent', 'bad', root / 'absent',
                    'bad', b'', 'bad', output=root / 'output', disclosure='restricted')
            self.assertFalse((root / 'output').exists())

    def test_rehashed_receipt_cannot_upgrade_claims_before_semantic_replay(self):
        worker = Path(replay.__file__).with_name('preserved_tool_worker_v1.py').read_bytes()
        pins = {'sourcePartsSha256': 'a'*64, 'runtimePartsSha256': 'b'*64,
            'runtimeRecipeSha256': sha256(b'{}').hexdigest()}
        report = {'schema': replay.NAME, **pins, 'workerSha256': sha256(worker).hexdigest(),
            'cases': [], 'child': {}, 'runtime': {}, 'claims': replay.CLAIMS, 'qualification': replay.QUALIFICATION}
        for name in ('fullGenesisReconstructionProven', 'sourceAuthorityProven', 'institutionalAcceptance'):
            changed = deepcopy(report); changed['claims'][name] = True
            files = {'worker.py': worker, 'report.json': dumps(changed), 'runtime-recipe.json': b'{}',
                'vectors.json': b'{}', 'stdout.log': b'', 'stderr.log': b''}
            files['manifest.json'] = dumps({'schema': replay.NAME,
                'files': [package._ref(p, b) for p, b in sorted(files.items())],
                'qualification': replay.QUALIFICATION})
            with self.subTest(claim=name), self.assertRaisesRegex(MuseumError, 'pins/results'):
                supplement._receipt(files, pins, [], {})

    def test_passive_receipt_never_accepts_undeclared_files(self):
        with self.assertRaisesRegex(MuseumError, 'exact receipt filenames'):
            supplement._receipt({'unexpected.py': b'print("execute")'}, {}, [], {})

    def test_recorded_modules_cannot_point_outside_original_byte_inventory(self):
        source = {'tools/museum/acquisition_canonical_v10.py': b'packet',
            'tools/museum/canonical_object_dossier_v3.py': b'dossier'}
        worker = b'worker'
        child = {'schema': 'STREAM_PRESERVED_TOOL_CHILD_RESULT_V1', 'cases': [],
            'modules': [{'module': '__main__', 'path': 'worker.py', 'sha256': sha256(worker).hexdigest()},
                *[{'module': p[:-3].replace('/', '.'), 'path': 'source/' + p,
                    'sha256': sha256(raw).hexdigest()} for p, raw in source.items()]],
            'python': '3.13.13 preserved', 'implementation': 'cpython',
            'isolation': {'isolated': True, 'noSite': True, 'noUserSite': True, 'ignoreEnvironment': True},
            'auditGuard': 'python_network_process_and_path_guard_v1', 'osSandbox': False}
        recipe = dumps({'pythonVersion': '3.13.13', 'files': []})
        child['readFiles'] = sorted([{'path': row['path'], 'sha256': row['sha256']}
            for row in child['modules']], key=lambda row: row['path'])
        replay.validate_child(child, [], source, recipe, worker)
        for mutate in (lambda c:c['modules'][0].update(path='../../operator-secrets.py'),
                lambda c:c['modules'][0].update(sha256='0'*64),
                lambda c:c['modules'].pop(), lambda c:c.update(osSandbox=True),
                lambda c:c['isolation'].update(noSite=False), lambda c:c.update(python='3.12.10 different'),
                lambda c:c['readFiles'].pop(),
                lambda c:c['readFiles'][0].update(path='operator/data.json'),
                lambda c:c.update(cases=[{'invented': True}])):
            changed = deepcopy(child); mutate(changed)
            with self.subTest(mutation=mutate), self.assertRaises(MuseumError):
                replay.validate_child(changed, [], source, recipe, worker)


if __name__ == '__main__':
    unittest.main()
