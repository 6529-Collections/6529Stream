"""Scoped capture must preserve inputs and never promote empty/partial execution."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from tools.development.run_current_acceptance import CREATION_SOURCE, TOOLS, capture, expected_cases, native_inventory, read_forge_json, source_files, test_results, validate_filters


class CurrentAcceptanceTests(unittest.TestCase):
    def test_capture_does_not_compile_unrelated_solidity_data_fixtures(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'repo'
            files = {CREATION_SOURCE: 'library StreamNativeAssemblyCreation {}',
                     'test/current/A.t.sol': 'contract A {}',
                     'test/fixtures/current-graph/products.json': json.dumps({'Product': 'smart-contracts/Product.sol'}),
                     'smart-contracts/Product.sol': 'contract Product {}',
                     'test/fixtures/safe/1.4.1.json': '{"exact":"safe bytes"}',
                     'test/fixtures/unrelated/Program.sol': 'import "../../../missing.sol";',
                     'foundry.toml': '[profile.current]\ntest = "test/current"\n'}
            files.update({name: '# tool' for name in TOOLS})
            for name, text in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding='utf-8')
            destination = Path(folder) / 'capture'
            with patch('tools.development.run_current_acceptance.subprocess.run', return_value=Mock(stdout='source-sha\n')):
                result = capture(root, destination, (('test/current/A.t.sol', 'A'),))
            self.assertNotIn('test/fixtures/unrelated/Program.sol', result['files'])
            self.assertEqual((destination / 'project/test/fixtures/safe/1.4.1.json').read_bytes(),
                             (root / 'test/fixtures/safe/1.4.1.json').read_bytes())
            before = (destination / 'capture.json').read_bytes()
            with self.assertRaises(FileExistsError):
                capture(root, destination, (('test/current/A.t.sol', 'A'),))
            self.assertEqual((destination / 'capture.json').read_bytes(), before)

    def test_import_closure_preserves_bytes_and_ignores_comments(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'test').mkdir()
            raw = (b'// import "./Missing.sol";\r\n/* import "./Absent.sol"; */\r\n'
                   b'import { B } from "./B.sol";\r\ncontract A { string constant URL="https://example.test"; }\r\n')
            (root / 'test/A.sol').write_bytes(raw)
            (root / 'test/B.sol').write_text('import "./A.sol"; contract B {}\n', encoding='utf-8')
            files = source_files(root, {'test/A.sol'})
            self.assertEqual(set(files), {'test/A.sol', 'test/B.sol'})
            self.assertEqual(files['test/A.sol'], raw)
            (root / 'test/B.sol').write_text('import "../../escape.sol";', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'Import escapes project'):
                source_files(root, {'test/A.sol'})

    def test_unsupported_import_is_not_silently_dropped(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'A.sol').write_text('import "package/B.sol";', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'requires relative imports'):
                source_files(root, {'A.sol'})

    def test_exact_suite_inventory_and_actual_cases_are_required(self):
        hosts = (('test/current/A.t.sol', 'A'), ('test/current/B.t.sol', 'B'))
        cases = {'testWorks()': {'status': 'Success'}}
        data = {s + ':' + n: {'test_results': dict(cases)} for s, n in hosts}
        self.assertEqual(test_results(data, hosts), {'passed': 2, 'failed': 0, 'skipped': 0})
        del data['test/current/B.t.sol:B']
        with self.assertRaisesRegex(ValueError, 'suite inventory differs'):
            test_results(data, hosts)
        data['test/current/B.t.sol:B'] = {'test_results': {}}
        with self.assertRaisesRegex(ValueError, 'No test cases executed'):
            test_results(data, hosts)
        data['test/current/B.t.sol:B']['test_results'] = {'setUp()': {'status': 'Failure'}}
        self.assertEqual(test_results(data, hosts)['failed'], 1)
        data['test/current/B.t.sol:B']['test_results'] = {'testLater()': {'status': 'Skipped'}}
        self.assertEqual(test_results(data, hosts)['skipped'], 1)

    def test_forge_json_retains_failures_after_compiler_preamble(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'tests.json'
            data = {'suite': {'test_results': {'testReject()': {'status': 'Failure', 'reason': 'mismatch'}}}}
            path.write_text('Compiling 3 files\n' + json.dumps(data), encoding='utf-8')
            self.assertEqual(read_forge_json(path), data)
            path.write_text('No tests found', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'No Forge JSON'):
                read_forge_json(path)

    def test_configured_filters_and_partial_per_host_results_are_rejected(self):
        config = {'invariant': {'check_interval': 1}}
        validate_filters(config)
        for field in ('match_test', 'no_match_test', 'match_path', 'no_match_path', 'skip'):
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'filters'):
                validate_filters(dict(config, **{field: 'testOne'}))
        hosts = (('test/current/A.t.sol', 'A'),)
        data = {'test/current/A.t.sol:A': {'test_results': {'testOne()': {'status': 'Success'}}}}
        with self.assertRaisesRegex(ValueError, 'test cases differ'):
            test_results(data, hosts, {'test/current/A.t.sol:A': ['testOne()', 'testTwo()']})

    def test_native_mutation_is_visible_and_expected_cases_come_from_host_abi(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            artifact = root / 'out/current/A.t.sol/A.json'
            artifact.parent.mkdir(parents=True)
            artifact.write_text(json.dumps({'abi': [
                {'type': 'function', 'name': 'testFuzzTuple', 'inputs': [
                    {'type': 'tuple[]', 'components': [{'type': 'uint256'}, {'type': 'address'}]}]},
                {'type': 'function', 'name': 'setUp', 'inputs': []}]}), encoding='utf-8')
            hosts = (('test/current/A.t.sol', 'A'),)
            self.assertEqual(expected_cases(root, hosts), {'test/current/A.t.sol:A': ['testFuzzTuple((uint256,address)[])']})
            before = native_inventory(root)
            artifact.write_text('{}', encoding='utf-8')
            self.assertNotEqual(native_inventory(root), before)

    def test_passing_property_requires_completed_budget(self):
        hosts = (('test/current/A.t.sol', 'A'),)
        case = {'status': 'Success', 'kind': {'Fuzz': {'runs': 1}}}
        data = {'test/current/A.t.sol:A': {'test_results': {'testProperty(uint256)': case}}}
        with self.assertRaisesRegex(ValueError, 'fuzz budget incomplete'):
            test_results(data, hosts)
        case['kind']['Fuzz']['runs'] = 256
        self.assertEqual(test_results(data, hosts)['passed'], 1)


if __name__ == '__main__':
    unittest.main()
