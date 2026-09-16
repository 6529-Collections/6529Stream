"""Reject stale or ambiguous native graph input before producing fixture files."""
import copy
import os
import tempfile
import unittest
from pathlib import Path

from tools.build.prepare_current_graph import CAMPAIGN_HOSTS, CREATION_NAME, CREATION_SOURCE, check_campaign_owner, host_coordinate, prepare, select_build, source_closure, validate_sources


class CurrentGraphInputsTests(unittest.TestCase):
    def test_explicit_safe_host_cannot_fall_back_to_stack(self):
        source, name = host_coordinate('test/current/StreamCurrentSafe.t.sol:StreamCurrentSafeTest')
        cache = {'files': {'test/current/StreamCurrentStack.t.sol': {'artifacts': {
            'StreamCurrentStackTest': {'0.8.19': {'current': {
                'path': 'StreamCurrentStack.t.sol/StreamCurrentStackTest.json', 'build_id': 'stack'}}}}}}}
        with self.assertRaisesRegex(ValueError, 'No current graph test host'):
            select_build(cache, ((source, name),))

    def test_invalid_host_coordinates_fail_before_writing(self):
        for value in ('test/../outside.t.sol:X', 'test/a.t.sol:X:Y', 'test/a.t.sol:.*',
                      'test\\a.t.sol:X', 'smart-contracts/A.sol:A', 'test//A.t.sol:A'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                host_coordinate(value)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with self.assertRaisesRegex(ValueError, 'Campaign host selection is fixed'):
                prepare(root, root / 'products.json', campaign=True, selected_hosts=CAMPAIGN_HOSTS)
            self.assertFalse((root / 'artifacts').exists())

    def test_astless_frozen_output_requires_real_rebuild(self):
        build = {'input': {'sources': {'A.sol': {'content': ''}}}, 'output': {'sources': {'A.sol': {'id': 0}}}}
        with self.assertRaisesRegex(ValueError, 'Compiler AST missing.*rebuild'):
            source_closure(build, {'A.sol'})

    def test_host_cache_selection_does_not_replace_creation_owner(self):
        source = "test/current/StreamNativeFinalityAssembly.t.sol"
        name = "StreamNativeFinalityAssemblyTest"
        entries = {"default": {"path": "StreamNativeFinalityAssembly.t.sol/" + name + ".json", "build_id": "a1"}}
        cache = {"files": {source: {"artifacts": {name: {"0.8.19": entries}}},
                           CREATION_SOURCE: {"artifacts": {CREATION_NAME: {"0.8.19": {"default": {
                               "path": "StreamNativeAssemblyCreation.sol/StreamNativeAssemblyCreation.json",
                               "build_id": "old"}}}}}}}
        self.assertEqual(select_build(cache), "a1")
        entries["other"] = dict(entries["default"], build_id="b2")
        with self.assertRaises(ValueError):
            select_build(cache)
        del cache["files"][source]
        with self.assertRaises(ValueError):
            select_build(cache)

    def test_campaign_uses_executed_host_context_instead_of_unrelated_current_suite(self):
        source, name = CAMPAIGN_HOSTS[0]
        cache = {"files": {source: {"artifacts": {name: {"0.8.19": {
            "current": {"path": Path(source).name + "/" + name + ".json", "build_id": "campaign"}}}}},
            "test/current/StreamCurrentStack.t.sol": {"artifacts": {
                "StreamCurrentStackTest": {"0.8.19": {"current": {
                    "path": "StreamCurrentStack.t.sol/StreamCurrentStackTest.json", "build_id": "unrelated"}}}}}}}
        self.assertEqual(select_build(cache), "unrelated")
        self.assertEqual(select_build(cache, CAMPAIGN_HOSTS), "campaign")
        del cache["files"][source]
        with self.assertRaises(ValueError):
            select_build(cache, CAMPAIGN_HOSTS)

    def test_dependency_closure_allows_unrelated_test_changes_but_rejects_stale_import(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            sources = {'Owner.sol': 'owner\n', 'Library.sol': 'library\n', 'OtherTest.sol': 'old test\n'}
            for name, value in sources.items():
                (root / name).write_bytes(value.encode('utf-8'))
            build = {'solcVersion': '0.8.19', 'input': {
                'settings': {'viaIR': True, 'evmVersion': 'paris', 'optimizer': {'enabled': True, 'runs': 200}},
                'sources': {n: {'content': v} for n, v in sources.items()}},
                'output': {'sources': {n: {'ast': {'absolutePath': n, 'nodes': []}} for n in sources}}}
            build['output']['sources']['Owner.sol']['ast']['nodes'] = [
                {'nodeType': 'ImportDirective', 'absolutePath': 'Library.sol'}]
            (root / 'OtherTest.sol').write_text('new test\n', encoding='utf-8')
            self.assertEqual(source_closure(build, {'Owner.sol'}), {'Owner.sol', 'Library.sol'})
            self.assertEqual(validate_sources(root, build, source_roots={'Owner.sol'}), [])
            with self.assertRaisesRegex(ValueError, 'Stale compiler source: OtherTest'):
                validate_sources(root, build)
            (root / 'Library.sol').write_text('changed dependency\n', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'Stale compiler source: Library'):
                validate_sources(root, build, source_roots={'Owner.sol'})

    def test_transitive_cycles_are_complete_and_missing_or_misbound_imports_fail(self):
        build = {'input': {'sources': {n: {'content': ''} for n in ('A.sol', 'B.sol', 'C.sol')}},
                 'output': {'sources': {n: {'ast': {'absolutePath': n, 'nodes': [
                     {'nodeType': 'ImportDirective', 'absolutePath': target}]}}
                     for n, target in [('A.sol', 'B.sol'), ('B.sol', 'C.sol'), ('C.sol', 'A.sol')]}}}
        self.assertEqual(source_closure(build, {'A.sol'}), {'A.sol', 'B.sol', 'C.sol'})
        bad = copy.deepcopy(build); del bad['output']['sources']['C.sol']
        with self.assertRaisesRegex(ValueError, 'Compiler dependency missing'):
            source_closure(bad, {'A.sol'})
        bad = copy.deepcopy(build); bad['output']['sources']['B.sol']['ast']['absolutePath'] = 'C.sol'
        with self.assertRaisesRegex(ValueError, 'Compiler AST source differs'):
            source_closure(bad, {'A.sol'})

    def test_creation_and_changed_test_have_independent_selected_contexts(self):
        def entry(source, name, ident):
            return {'artifacts': {name: {'0.8.19': {'default': {
                'path': Path(source).name + '/' + name + '.json', 'build_id': ident}}}}}
        source = 'test/current/StreamCurrentNativeSettlement.t.sol'; name = 'StreamCurrentNativeSettlementTest'
        cache = {'files': {CREATION_SOURCE: entry(CREATION_SOURCE, CREATION_NAME, 'old-creation'),
                           source: entry(source, name, 'new-test')}}
        self.assertEqual(select_build(cache, ((CREATION_SOURCE, CREATION_NAME),)), 'old-creation')
        self.assertEqual(select_build(cache, ((source, name),)), 'new-test')
        # A missing actual creation owner must never fall back to a newer host.
        del cache['files'][CREATION_SOURCE]
        with self.assertRaises(ValueError):
            select_build(cache, ((CREATION_SOURCE, CREATION_NAME),))

    def test_only_the_active_campaign_child_can_prepare_shared_inputs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            lease = root / "cache/current-graph.campaign.lock"
            lease.parent.mkdir()
            check_campaign_owner(root, False)
            lease.write_text(str(os.getppid()), encoding="ascii")
            check_campaign_owner(root, True)
            with self.assertRaises(ValueError):
                check_campaign_owner(root, False)
            lease.write_text("different-owner", encoding="ascii")
            with self.assertRaises(ValueError):
                check_campaign_owner(root, True)

    def test_changed_source_cannot_reuse_a_passing_old_build(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "Product.sol").write_bytes(b"original\n")
            build = {"solcVersion": "0.8.19", "input": {
                "settings": {"viaIR": True, "evmVersion": "paris", "optimizer": {"enabled": True, "runs": 200}},
                "sources": {"Product.sol": {"content": "original\n"}}}}
            self.assertEqual(validate_sources(root, build), [])
            (root / "Product.sol").write_bytes(b"changed\n")
            with self.assertRaises(ValueError):
                validate_sources(root, build)
            (root / "Product.sol").write_bytes(b"original\r\n")
            self.assertEqual(validate_sources(root, build), ["Product.sol"])
            wrong = copy.deepcopy(build)
            wrong["input"]["settings"]["viaIR"] = False
            with self.assertRaises(ValueError):
                validate_sources(root, wrong)
            wrong = copy.deepcopy(build)
            wrong["input"]["sources"] = {"../Product.sol": {"content": "original\n"}}
            with self.assertRaises(ValueError):
                validate_sources(root, wrong)


if __name__ == "__main__":
    unittest.main()
