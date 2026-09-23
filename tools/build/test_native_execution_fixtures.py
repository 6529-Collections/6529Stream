"""Focused source and permission controls for execution-only fixture projects."""
import hashlib
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest
from unittest import mock

from tools.build.current_native_execution_view import recheck_execution_project
from tools.build.native_execution_fixtures import _profile_read_scopes, _safe, _tree, stage_execution_project
from tools.development.run_native_execution_view import require_execution_profile


class ExecutionFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'source'
        self.repo.mkdir()
        self.project = self.root / 'native'
        self.project.mkdir()
        self.view = self.root / 'view-project'
        self.source = 'test/current/Case.t.sol'
        source = b'pragma solidity 0.8.19; contract CaseTest { function testCase() public {} }\n'
        self._write(self.repo, self.source, source)
        self._write(self.project, self.source, source)
        self._write(self.repo, 'test/fixtures/safe/1.4.1.json', b'{"safe":true}\n')
        self._write(self.repo, 'test/fixtures/accidental.sol', b'contract Accidental {}\n')
        self._write(self.repo, 'docs/schemas/preservation/reference.json', b'{"schema":1}\n')
        self._write(self.repo, 'private/outside.json', b'{"unscoped":true}\n')
        source_config = '''[profile.default]
optimizer = true
fs_permissions = [{ access = "read", path = "./test/fixtures" }]
[profile.current]
via_ir = true
fs_permissions = [
    { access = "read", path = "./test/fixtures" },
    { access = "read", path = "./docs/schemas/preservation" },
    { access = "read", path = "./" },
    { access = "read-write", path = "./artifacts/native-assembly" },
]
'''.encode()
        native_config = '''[profile.default]
optimizer = true
gas_limit = 10000000000
memory_limit = 1073741824
code_size_limit = 2000000
fs_permissions = [{ access = "read", path = "./test/fixtures" }]
[profile.current]
via_ir = true
optimizer_runs = 200
'''.encode()
        self._write(self.repo, 'foundry.toml', source_config)
        self._write(self.project, 'foundry.toml', native_config)
        self.original_config = tomllib.loads(native_config.decode())
        self._git('init', '-q')
        self._git('config', 'user.name', 'Fixture Test')
        self._git('config', 'user.email', 'fixture@example.invalid')
        self._git('add', '.')
        self._git('commit', '-qm', 'source fixture')
        self.commit = self._git('rev-parse', 'HEAD').stdout.decode().strip()
        self.sources = {self.source: hashlib.sha256(source).hexdigest()}

    def _write(self, root, name, raw):
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)

    def _git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args],
                              capture_output=True, check=True)

    def test_missing_scoped_fixtures_and_permissions_are_staged_without_solidity(self):
        self.assertFalse((self.project / 'test/fixtures/safe/1.4.1.json').exists())
        result = stage_execution_project(self.project, self.view, self.sources,
                                         self.repo, self.commit)
        self.assertEqual(result['readScopes'], ['docs/schemas/preservation', 'test/fixtures'])
        self.assertEqual((self.view / 'test/fixtures/safe/1.4.1.json').read_bytes(), b'{"safe":true}\n')
        self.assertTrue((self.view / 'docs/schemas/preservation/reference.json').is_file())
        self.assertFalse((self.view / 'test/fixtures/accidental.sol').exists())
        self.assertFalse((self.view / 'private/outside.json').exists())
        self.assertFalse((self.project / 'test/fixtures/safe/1.4.1.json').exists())
        config = tomllib.loads((self.view / 'foundry.toml').read_text(encoding='utf-8'))
        self.assertEqual(config['profile']['current']['fs_permissions'], [
            {'access': 'read', 'path': './docs/schemas/preservation'},
            {'access': 'read', 'path': './test/fixtures'},
        ])
        del config['profile']['current']['fs_permissions']
        self.assertEqual(config, self.original_config)
        recheck_execution_project(self.view, result['projectHashes'])
        (self.view / 'test/fixtures/safe/1.4.1.json').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'authenticated fixtures changed'):
            recheck_execution_project(self.view, result['projectHashes'])

    def test_changed_native_source_is_rejected_before_materialization(self):
        (self.project / self.source).write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Execution source differs'):
            stage_execution_project(self.project, self.view, self.sources,
                                    self.repo, self.commit)
        self.assertFalse(self.view.exists())

    def test_escaping_source_permission_is_rejected(self):
        path = self.repo / 'foundry.toml'
        path.write_bytes(path.read_bytes().replace(
            b'{ access = "read", path = "./" },',
            b'{ access = "read", path = "./../private" },'))
        self._git('add', 'foundry.toml')
        self._git('commit', '-qm', 'escape attempt')
        commit = self._git('rev-parse', 'HEAD').stdout.decode().strip()
        with self.assertRaisesRegex(ValueError, 'Unsafe source path'):
            stage_execution_project(self.project, self.view, self.sources,
                                    self.repo, commit)
        self.assertFalse(self.view.exists())

    def test_default_and_current_profiles_keep_distinct_scoped_reads(self):
        raw = self._git('show', 'HEAD:foundry.toml').stdout
        self.assertEqual(_profile_read_scopes(raw, 'default'), ['test/fixtures'])
        self.assertEqual(_profile_read_scopes(raw, 'current'),
                         ['docs/schemas/preservation', 'test/fixtures'])

    def test_current_inherits_default_permissions_when_unset(self):
        path = self.repo / 'foundry.toml'
        block = (b'fs_permissions = [\n'
                 b'    { access = "read", path = "./test/fixtures" },\n'
                 b'    { access = "read", path = "./docs/schemas/preservation" },\n'
                 b'    { access = "read", path = "./" },\n'
                 b'    { access = "read-write", path = "./artifacts/native-assembly" },\n'
                 b']\n')
        raw = path.read_bytes()
        self.assertIn(block, raw)
        raw = raw.replace(block, b'')
        path.write_bytes(raw)
        self._git('add', 'foundry.toml')
        self._git('commit', '-qm', 'inherit default reads')
        commit = self._git('rev-parse', 'HEAD').stdout.decode().strip()
        self.assertEqual(_profile_read_scopes(raw, 'current'), ['test/fixtures'])
        result = stage_execution_project(self.project, self.view, self.sources,
                                         self.repo, commit, profile='current')
        self.assertEqual(result['readScopes'], ['test/fixtures'])
        self.assertFalse((self.view / 'docs/schemas/preservation/reference.json').exists())

    def test_absent_execution_profile_in_native_config_preserves_other_fields(self):
        config = self.project / 'foundry.toml'
        raw = config.read_bytes()
        config.write_bytes(raw.split(b'[profile.current]')[0])
        baseline = tomllib.loads(config.read_text(encoding='utf-8'))
        stage_execution_project(self.project, self.view, self.sources,
                                self.repo, self.commit, profile='current')
        updated = tomllib.loads((self.view / 'foundry.toml').read_text(encoding='utf-8'))
        self.assertEqual(updated['profile']['current'].pop('fs_permissions'), [
            {'access': 'read', 'path': './docs/schemas/preservation'},
            {'access': 'read', 'path': './test/fixtures'},
        ])
        self.assertEqual(updated['profile']['current'], {})
        del updated['profile']['current']
        self.assertEqual(updated, baseline)

    def test_runner_requires_the_staged_permission_profile(self):
        snapshot = {'executionProject': 'sealed/project', 'executionProfile': 'default'}
        require_execution_profile(snapshot, 'default')
        with self.assertRaisesRegex(ValueError, 'profile differs'):
            require_execution_profile(snapshot, 'current')

    def test_tree_object_cannot_impersonate_source_commit(self):
        tree = self._git('rev-parse', 'HEAD^{tree}').stdout.decode().strip()
        with self.assertRaisesRegex(ValueError, 'not a commit'):
            stage_execution_project(self.project, self.view, self.sources,
                                    self.repo, tree)
        self.assertFalse(self.view.exists())

    def test_windows_aliases_are_rejected_before_materialization(self):
        entries = _tree(self.repo, self.commit)
        raw = b'{"same":true}\n'
        oid = subprocess.run(['git', '-C', str(self.repo), 'hash-object', '-w', '--stdin'],
                             input=raw, capture_output=True, check=True).stdout.decode().strip()
        entries['test/fixtures/Token.json'] = oid
        entries['test/fixtures/token.json'] = oid
        with mock.patch('tools.build.native_execution_fixtures._tree', return_value=entries):
            with self.assertRaisesRegex(ValueError, 'Windows-staged path alias'):
                stage_execution_project(self.project, self.view, self.sources,
                                        self.repo, self.commit)
        self.assertFalse(self.view.exists())

    def test_unsafe_windows_components_cannot_bypass_solidity_filter(self):
        for path in ('test/fixtures/Accidental.sol.', 'test/fixtures/CON.json',
                     'test/fixtures/name ', 'test/fixtures/AUX', 'test/fixtures/../secret'):
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'Unsafe'):
                _safe(path)


if __name__ == '__main__':
    unittest.main()
