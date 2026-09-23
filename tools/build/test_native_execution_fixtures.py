"""Focused source and permission controls for execution-only fixture projects."""
import hashlib
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

from tools.build.current_native_execution_view import recheck_execution_project
from tools.build.native_execution_fixtures import stage_execution_project


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


if __name__ == '__main__':
    unittest.main()
